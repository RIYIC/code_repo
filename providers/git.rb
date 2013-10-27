action :pull do
    target_path = new_resource.target_path
    repo_url = new_resource.url
    revision = new_resource.revision
    owner = new_resource.owner
    group = new_resource.group


    # preparamos o entorno
    group group

    user owner do
      group group
    end

    directory target_path do
      owner owner
      group group
      recursive true
    end

    keyfile = "/tmp/sshkey"
    ssh_wrapper = "/tmp/ssh_wrapper.sh"
    
    # seteamos os parametros necesarios para descargar desde un repo ssh con key
    if new_resource.credential

      Chef::Log.info "Creating keyfile #{keyfile} and ssh wrapper #{ssh_wrapper}"
      file keyfile do
          backup false
          owner owner
          group group
          mode "0600"
          content new_resource.credential
      end

      template ssh_wrapper do
          cookbook "code_repo"
          source "ssh_wrapper.sh.erb"
          owner owner
          group group
          mode 00700
          variables(
            :keyfile => keyfile
          )
      end

      ruby_block "before pull" do
        block do
          ENV["GIT_SSH"] = ssh_wrapper
        end
      end
    end

    #
    # descargamos o codigo da app, ou actualizamos o existente
    #
    Chef::Log.info("Git pull #{target_path}")
    git target_path do
      repository  repo_url
      reference   revision
      action      :sync
      user        owner
      group       group
    end

    if new_resource.credential
      Chef::Log.info("Cleaning keyfile and environment")
      # borramos as keys ssh do repo e a variable de entorno
      ruby_block "After pull" do
        block do
          ::File.delete(keyfile)
          ::File.delete(ssh_wrapper)
          ENV.delete("GIT_SSH")
        end
      end
    end

    new_resource.updated_by_last_action(true)

end