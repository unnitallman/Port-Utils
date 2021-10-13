require 'octokit'

class AutoRebaseService
  attr_reader :client, :repo

  def initialize(token, repo)
    @repo   = repo 
    @client = Octokit::Client.new(access_token: token)
  end

  def rebase_all_pull_requests!
    open_pull_requests.each do |pr|
      rebase pr
    end
  end

  private 

    def rebase(pr_number)
      pr = client.pull_request(repo, pr_number)
      author = pr.head.user.login
      comment_text = "@#{author} auto-rebase failed. Rebase manually."

      unless rebase_with_master(pr) 
        post_failure_comment(pr, comment_text)
      end
    end

    def post_failure_comment(pr, comment_text)
      client.add_comment(pr.head.repo.full_name, pr.number, comment_text)
      exit(1)
    end

    def rebase_with_master(pr)
      head_repo   = pr.head.repo.full_name
      head_branch = pr.head.ref
      base_repo   = pr.base.repo.full_name
      base_branch = pr.base.ref

      user_name = pr.user.login
      user_email = "#{user_name}@users.noreply.github.com"

      results = []

      results << system("git config --global user.email \"#{user_email}\"")
      results << system("git config --global user.name \"#{user_name}\"")

      results << system("set -o xtrace")

      # make sure branches are up-to-date
      results << system("git fetch origin")

      # do the rebase
      results << system("git checkout origin/#{head_branch} -b #{head_branch}")
      results << system("git rebase origin/#{base_branch}")

      # push back
      results << system("git push --force-with-lease origin #{head_branch}")

      results.all?    
    end

    def open_pull_requests
      @_open_pull_requests ||= client.pull_requests(repo).select{|pr| pr.state == "open" }.map(&:number)
    end
end

token = ENV["AUTOREBASE_TOKEN"]
repo  = ENV["REPO_NAME"]

AutoRebaseService.new(token, repo).rebase_all_pull_requests!