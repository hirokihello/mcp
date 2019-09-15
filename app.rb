# frozen_string_literal: true
require 'sinatra'
require 'docker'
require 'sinatra/reloader'
require 'pry-byebug'

set :server_settings, :timeout => 60

get '/' do
  image = Docker::Image.create('fromImage' => 'ruby:2.6.3')
  image.tag('repo' => 'ruby-base-hirokihello', 'tag' => 'latest', force: true)
  app_container = Docker::Container.create(
    'Cmd' => ['/bin/bash'],
    'Image' => 'ruby-base-hirokihello:latest',
    'OpenStdin' => true,
    'OpenStdout' => true,
    'tty' => true,
    'logs' => true
  )
  db_container = Docker::Container.create(
    'Image' => 'mysql:5.7'
  )
  app_container.start
  puts app_container.exec(['apt', 'update'], stdout: true, tty: true)
  puts app_container.exec(['apt', 'install', 'git'], stdout: true, tty: true)
  puts app_container.exec(['git', 'clone', 'https://github.com/hirokihello/rails-realworld-example-app.git'], stdout: true, tty: true)
  puts app_container.exec(['ls', '-l'], stdout: true, tty: true)
  command = ["/bin/bash", "-c", "echo -n \"I'm a TTY!\""]
  puts app_container.exec(command, tty: true)
  app_container.stop
  "hello"
end