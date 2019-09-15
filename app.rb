# frozen_string_literal: true
require 'sinatra'
require 'docker'
require 'sinatra/reloader'
require 'pry-byebug'

get '/' do
  image = Docker::Image.create('fromImage' => 'ruby:2.6.3')
  image.tag('repo' => 'ruby-base-hirokihello', 'tag' => 'latest', force: true)
  container = Docker::Container.create(
    'Cmd' => ['/bin/bash'],
    'Image' => 'ruby-base-hirokihello:latest',
    'OpenStdin' => true,
    'OpenStdout' => true,
    'tty' => true,
    'logs' => true
  )
  container.start
  binding.pry
  puts container.exec(['apt', 'update'], stdout: true, tty: true)
  puts container.exec(['ls', '-l'], stdout: true, tty: true)
  container.exec(['apt', 'install', 'git'], stdout: true, tty: true)
  container.exec(['ssh', '-T', 'git@git.com'], stdout: true, tty: true)
  container.exec(['curl', 'https://example.com'], stdout: true, tty: true)
  puts "pwd command"
  puts container.exec(['git', 'clone', 'https://github.com/hirokihello/rails-realworld-example-app.git'], stdout: true, tty: true)
  command = ["/bin/bash", "-c", "echo -n \"I'm a TTY!\""]
  puts container.exec(command, tty: true)
  container.kill
  "hello"
end