# Tasks for remote building on builder hosts
if File.exist?("#{ENV['HOME']}/.packaging/#{@builder_data_file}")
  namespace 'pl' do
    task :remote_build, :host, :treeish, :task do |t, args|
      host                    = args.host
      treeish                 = args.treeish
      task                    = args.task
      remote_repo             = remote_bootstrap(host, treeish)
      STDOUT.puts "Beginning package build on #{host}"
      remote_ssh_cmd(host, "cd #{remote_repo} ; rake #{task} ANSWER_OVERRIDE=no")
      rsync_from("#{remote_repo}/pkg/", host, 'pkg/')
      remote_ssh_cmd(host, "rm -rf #{remote_repo}")
      STDOUT.puts "packages from #{host} staged in pkg/ directory"
    end

    desc "Execute release_deb_rc full build set on remote debian build host"
    task :remote_deb_rc => :fetch do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pl:release_deb_rc")
    end

    desc "Execute release_deb_final full build set on remote debian build host"
    task :remote_deb_final => :fetch do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@deb_build_host, 'HEAD', "pl:release_deb_final")
    end

    desc "Execute release_rpm_rc full build set on remote rpm build host"
    task :remote_rpm_rc => :fetch do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pl:release_rpm_rc")
    end

    desc "Execute release_deb_final full build set on remote rpm build host"
    task :remote_rpm_final => :fetch do
      Rake::Task["pl:remote_build"].reenable
      Rake::Task["pl:remote_build"].invoke(@rpm_build_host, 'HEAD', "pl:release_rpm_final")
    end

    desc "Execute package:apple on remote apple build host"
    task :remote_dmg => :fetch do
      # Because we use rvmsudo for apple, we end up replicating the :remote_build task
      host                    = @osx_build_host
      treeish                 = 'HEAD'
      task                    = "package:apple"
      remote_repo             = remote_bootstrap(host, treeish)
      puts "Beginning package build on #{host}"
      remote_ssh_cmd(host, "cd #{remote_repo} ; rvmsudo rake #{task}")
      rsync_from("#{remote_repo}/pkg/apple", host, 'pkg/')
      remote_ssh_cmd(host, "sudo rm -rf #{remote_repo}")
      STDOUT.puts "packages from #{host} staged in pkg/ directory"
    end if @build_dmg

    desc "UBER RC build: build and ship RC tar, gem (as applicable), remote dmg, remote deb, remote rpm"
    task :uber_rc do
      Rake::Task["package:gem"].invoke if @build_gem
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:remote_deb_rc"].invoke
      Rake::Task["pl:remote_rpm_rc"].execute
      Rake::Task["pl:remote_dmg"].execute if @build_dmg
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote_freight_devel"].invoke
    end

    desc "UBER FINAL build: build and ship FINAL tar, gem (as applicable), remote dmg, remote deb, remote rpm"
    task :uber_final do
      Rake::Task["package:gem"].invoke if @build_gem
      Rake::Task["package:tar"].execute
      Rake::Task["pl:sign_tar"].invoke
      Rake::Task["pl:remote_deb_final"].invoke
      Rake::Task["pl:remote_rpm_final"].execute
      Rake::Task["pl:remote_dmg"].execute if @build_dmg
      Rake::Task["pl:uber_ship"].execute
      Rake::Task["pl:remote_freight_final"].invoke
    end
  end
end
