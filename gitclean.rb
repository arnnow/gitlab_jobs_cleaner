#!/usr/bin/ruby
#

require 'gitlab'
require 'pp'
require 'date'
begin
  require 'logger/colors'
rescue LoadError
else
  Logger::Colors.send(:remove_const,:SCHEMA) # This is dirty but it fixes the 'warning: already initialized constant SCHEMA'
  Logger::Colors::SCHEMA = {
    STDOUT => %w[light_blue green brown red purple cyan],
    STDERR => %w[light_blue green yellow light_red light_purple light_cyan],
  }
end



LOGLEVEL ||= Logger::DEBUG
$log = Logger.new(STDOUT)
$log.level = LOGLEVEL

OLDER_THAN = 86400
ENDPOINT = ''
TOKEN = ''
GITLABPROJECTSPAGES = 100
GITLABJOBSPAGES = 100

Gitlab.configure do |config|
  config.endpoint       = ENDPOINT  # API endpoint URL, default: ENV['GITLAB_API_ENDPOINT']
  config.private_token  = TOKEN  # user's private token or OAuth2 access token, default: ENV['GITLAB_API_PRIVATE_TOKEN']
end

projects = Gitlab.projects(per_page: GITLABPROJECTSPAGES)
projects.auto_paginate do |project|
  $log.info "Project : " + project.name_with_namespace
  $page = 0
  while $page < 100 do
    jobs = Gitlab.jobs(project.id,{ per_page: GITLABJOBSPAGES , page: $page})
    $page += 1
    if !jobs.any?
      $page = 101 
    end
    jobs.each do |job|
      if Time.parse(job.created_at) < Time.now - OLDER_THAN
        begin
          Gitlab.job_erase(project.id,job.id)
          $log.info project.name + " Success  " + job.id.to_s + ' ' + job.created_at
        rescue
          $log.error project.name + " Failed " + job.id.to_s + ' ' + job.created_at
          next
        end
      end
    end
  end
end
