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
      branch = pr.head.ref
      author = pr.head.user.login
      comment_text = "@#{author} auto-rebase failed. Rebase manually."

      p "---------------------"
      p pr.number
      p pr.rebaseable?
      p "---------------------"

      if pr.rebaseable?
        rebase_with_master(branch) rescue post_failure_comment(pr, comment_text)
      else
        post_failure_comment(pr, comment_text)
      end
    end

    def post_failure_comment(pr, comment_text)
      client.add_comment(pr.head.repo.full_name, pr.number, comment_text)
    end

    def rebase_with_master(branch)
      `git fetch && git checkout #{branch} && git rebase master && git push -f`
    end

    def open_pull_requests
      @_open_pull_requests ||= client.pull_requests(repo).select{|pr| pr.state == "open" }.map(&:number)
    end
end

token = ENV["AUTOREBASE_TOKEN"]
repo  = ENV["REPO_NAME"]

AutoRebaseService.new(token, repo).rebase_all_pull_requests!