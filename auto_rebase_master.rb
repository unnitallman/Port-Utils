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

      if pr.rebaseable?
        rebase_with_master(pr) rescue post_failure_comment(pr, comment_text)
      else
        post_failure_comment(pr, comment_text)
      end
    end

    def post_failure_comment(pr, comment_text)
      client.add_comment(pr.head.repo.full_name, pr.number, comment_text)
    end

    def rebase_with_master(pr)
      head_repo   = pr.head.repo.full_name
      head_branch = pr.head.ref
      base_repo   = pr.base.repo.full_name
      base_branch = pr.base.ref

      user_name = pr.user.login
      user_email = "#{user_name}@users.noreply.github.com"

      `git remote set-url origin https://#{base_repo}.git`
      `git config --global user.email "#{user_email}"`
      `git config --global user.name "#{user_name}"`

      `git remote add fork https://#{head_repo}.git`

      `set -o xtrace`

      # make sure branches are up-to-date
      `git fetch origin #{base_branch}`
      `git fetch fork #{head_branch}`

      # do the rebase
      `git checkout -b fork/#{head_branch} fork/#{head_branch}`
      `git rebase origin/#{base_branch}`

      # push back
      `git push --force-with-lease fork fork/#{head_branch}:#{head_branch}`
    end

    def open_pull_requests
      @_open_pull_requests ||= client.pull_requests(repo).select{|pr| pr.state == "open" }.map(&:number)
    end
end

token = ENV["AUTOREBASE_TOKEN"]
repo  = ENV["REPO_NAME"]

AutoRebaseService.new(token, repo).rebase_all_pull_requests!