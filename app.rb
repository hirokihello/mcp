# frozen_string_literal: true
require 'sinatra'
require 'docker'
require 'sinatra/reloader'
require 'pry-byebug'

set :server_settings, :timeout => 300

get '/' do
  network = Docker::Network.get('ci-network')
  network = Docker::Network.create('ci-network') unless network

  app_image = Docker::Image.create('fromImage' => 'ruby:2.6.3')
  app_image.tag('repo' => 'ruby-base-hirokihello', 'tag' => 'latest', force: true)

  db_image = Docker::Image.create('fromImage' => 'mysql:5.6')
  db_image.tag('repo' => 'mysql-base-hirokihello', 'tag' => 'latest', force: true)

  app = Docker::Container.create(
    'Cmd' => ['/bin/bash'],
    'Image' => 'ruby-base-hirokihello:latest',
    'OpenStdin' => true,
    'OpenStdout' => true,
    'tty' => true,
    'logs' => true,
    'name' => 'ci_app_container',
    'net' => 'ci-network',
    'Env' => [
      'MYSQL_ROOT_PASSWORD=password'
    ]
  )

  db = Docker::Container.create(
    'Cmd' => ["/bin/bash"],
    'Image' => 'mysql-base-hirokihello:latest',
    'OpenStdin' => true,
    'OpenStdout' => true,
    'tty' => true,
    'logs' => true,
    'name' => 'ci_db_container',
    'net' => 'ci-network',
    'Env' => [
      'MYSQL_ROOT_PASSWORD=password'
    ]
  )

  network.connect('ci_app_container')
  network.connect('ci_db_container')
  app.start
  db.start

  puts app.exec(['apt', 'update'], stdout: true, tty: true)
  # # puts "upgradeを走らせる"
  # # puts app.exec(['apt', 'upgrade', '-qq', '-y'], stdout: true, tty: true)
  # # puts app.exec(['apt', 'install', 'git'], stdout: true, tty: true)
  puts app.exec(['apt', 'install', 'dnsutils', '-qq', '-y'], stdout: true, tty: true)
  puts "nslookupをうつ"
  puts app.exec(['dig', 'ci_db_container'], stdout: true, tty: true)

  #gitからひっぱてくる
  # puts app.exec(['git', 'clone', 'https://github.com/hirokihello/rails-realworld-example-app.git'], stdout: true, tty: true)
# binding.pry
  # command = ["/bin/bash", "-c", "echo -n \"I'm a TTY!\""]
  # puts app.exec(command, tty: true)
  app.stop
  db.stop
  app.remove
  db.remove
  "hello"
end

private

  def create_containers
  end