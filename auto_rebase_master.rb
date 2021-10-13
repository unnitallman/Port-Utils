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
      head_branch = pr.head.ref
      base_branch = pr.base.ref

      user_name = pr.user.login
      user_email = "#{user_name}@users.noreply.github.com"

      git_commands = []

      git_commands << "git config --global user.email \"#{user_email}\""
      git_commands << "git config --global user.name \"#{user_name}\""

      git_commands << "git remote add fork https://github.com/#{repo}.git"
      git_commands << "git fetch fork"

      # do the rebase
      git_commands << "git checkout fork/#{head_branch} -b #{head_branch}"
      git_commands << "git rebase fork/#{base_branch}"

      # push back
      git_commands << "git push --force-with-lease fork #{head_branch}"

      puts git_commands.join(" && ")

      system(git_commands.join(" && "))
    end

    def open_pull_requests
      @_open_pull_requests ||= client.pull_requests(repo).select{|pr| pr.state == "open" }.map(&:number)
    end
end

token = ENV["AUTOREBASE_TOKEN"]
repo  = ENV["REPO_NAME"]

AutoRebaseService.new(token, repo).rebase_all_pull_requests!