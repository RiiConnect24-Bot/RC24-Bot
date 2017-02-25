module SerieBot
  module Helper
    def self.is_admin?(member)
      Config.bot_owners.include?(member)
    end

    def self.setup_role_storage?(name, id)
      # Set all to defaults
      Config.settings['role'] = [] if Config.settings['role'].nil?
      Config.settings['role'][id] = [] if Config.settings['role'][id].nil?
      Config.settings['role'][id][name] = 0 if Config.settings['role'][id][name].nil?
      return Config.settings['role'][id][name]
    end

    # It's okay for us to add server specific commands as we aren't
    # doing anything on other servers.
    def self.is_developer?(event)
      # Check if config already has a role
      developer_role = setup_role_storage?('developer', event.server.id)

      if developer_role == 0
        # Set to default
        developer_role = Helper.role_from_name(event.server, 'Developers').id
        # Is it nil because of no role?
        if developer_role.nil?
          event.respond("I wasn't able to find the role \"Developers\" for dev-level tasks! See `#{Config.prefix}config help` for information.")
          return false
        else
          event.respond("Role \"dev\" set to default. Use `#{Config.prefix}config setrole dev <mod role name>` to change otherwise.")
        end
      end
      # Check if the member has the ID of the developers role
      return event.user.role?(event.server.role(Config.settings['role'][event.server.id]['developer']))
    end

    def self.is_bot_helper?(event)
      # Check if config already has a role
      bot_helper_role = Config.settings['role']['bot_helper']
      if bot_helper_role.nil?
        # Set to default
        bot_helper_role = Helper.role_from_name(event.server, 'Bot Helpers').id
        if bot_helper_role.nil?
          # Chances are they won't need this role, so don't say anything.
          return false
        else
          event.respond("Role \"Bot Helpers\" set to default. Use `#{Config.prefix}config setrole bot <mod role name>` to change otherwise. (Chances are, you won't need to.)")
        end
      end
      # Check if the member has the ID of the bot helpers role
      return event.user.role?(event.server.role(bot_helper_role))
    end

    def self.is_moderator?(event)
      # Check if the member has the ID of the developers role
      # Check if config already has a role
      moderators_role = Config.settings['role']['moderators']
      if moderators_role.nil?
        # Set to default
        moderators_role = Helper.role_from_name(event.server, 'Moderators').id
        if moderators_role.nil?
          event.respond("I wasn't able to find the role \"Moderators\" for moderation tasks! See `#{Config.prefix}config help` for information.")
          return false
        else
          event.respond("Role \"moderators\" set to default. Use `#{Config.prefix}config setrole mod <mod role name>` to change otherwise.")
        end
      end
      # Check if the member has the ID of the moderators role
      return event.user.role?(event.server.role(moderators_role))
    end

    def self.quit
      puts 'Exiting...'
      exit
    end


    # Loading/saving of morpher messages
    def self.load_morpher
      folder = 'data'
      codes_path = "#{folder}/morpher.yml"
      FileUtils.mkdir(folder) unless File.exist?(folder)
      unless File.exist?(codes_path)
        File.open(codes_path, "w") { |file| file.write("---\n:version: 1\n") }
      end
      Morpher.messages = YAML.load(File.read(codes_path))
    end

    def self.save_morpher
      File.open('data/morpher.yml', 'w+') do |f|
      f.write(Morpher.messages.to_yaml)
      end
    end

    # Loading/saving of settings
    def self.save_settings
      File.open('data/settings.yml', 'w+') do |f|
        f.write(Config.settings.to_yaml)
      end
    end

    def self.load_settings
      folder = 'data'
      settings_path = "#{folder}/settings.yml"
      FileUtils.mkdir(folder) unless File.exist?(folder)
      unless File.exist?(settings_path)
        puts Rainbow("[ERROR] I wasn't able to find data/settings.yml! Please grab the example from the repo.").red
      end
      Config.settings = YAML.load(File.read(settings_path))
    end

    # Loading/saving of codes
    def self.load_codes
      folder = 'data'
      codes_path = "#{folder}/codes.yml"
      FileUtils.mkdir(folder) unless File.exist?(folder)
      unless File.exist?(codes_path)
      File.open(codes_path, "w") { |file| file.write("---\n:version: 1\n") }
      end
      Codes.codes = YAML.load(File.read(codes_path))
    end

    def self.save_codes
      File.open('data/codes.yml', 'w+') do |f|
      f.write(Codes.codes.to_yaml)
      end
    end

    # Downloads an avatar when given a `user` object.
    # Returns the path of the downloaded file.
    def self.download_avatar(user, folder)
      url = Helper.avatar_url(user)
      path = download_file(url, folder)
      path
    end

    def self.avatar_url(user, size = 256)
      url = user.avatar_url
      uri = URI.parse(url)
      filename = File.basename(uri.path)

      filename = if filename.start_with?('a_')
             filename.gsub('.jpg', '.gif')
           else
             filename.gsub('.jpg', '.png')
           end
      url << '?size=256'
      url = "https://cdn.discordapp.com/avatars/#{user.id}/#{filename}?size=#{size}"
      url
    end

    # Download a file from a url to a specified folder.
    # If no name is given, it will be taken from the url.
    # Returns the full path of the downloaded file.
    def self.download_file(url, folder, name = nil)
      if name.nil?
        uri = URI.parse(url)
        filename = File.basename(uri.path)
        name = filename if name.nil?
      end

      path = "#{folder}/#{name}"

      FileUtils.mkdir(folder) unless File.exist?(folder)
      FileUtils.rm(path) if File.exist?(path)

      File.new path, 'w'
      File.open(path, 'wb') do |file|
        file.write open(url).read
      end

      path
    end

    # If the user passed is a bot, it will be ignored.
    # Returns true if the user was a bot.
    def self.ignore_bots(user)
      if user.bot_account?
        event.bot.ignore_user(event.user)
        return true
      else
        return false
      end
    end

    def self.upload_file(channel, filename)
      channel.send_file File.new([filename].sample)
      puts "Uploaded `#{filename} to \##{channel.name}!"
    end

    # Accepts a message, and returns the message content, with all mentions + channels replaced with @user#1234 or #channel-name
    def self.parse_mentions(bot, content)
      # Replce user IDs with names
      loop do
      match = /<@\d+>/.match(content)
      break if match.nil?
      # Get user
      id = match[0]
      # We have to sub to just get the numerical ID.
      num_id = /\d+/.match(id)[0]
      content = content.sub(id, get_user_name(num_id, bot))
      end
      loop do
      match = /<@!\d+>/.match(content)
      break if match.nil?
      # Get user
      id = match[0]
      # We have to sub to just get the numerical ID.
      num_id = /\d+/.match(id)[0]
      content = content.sub(id, get_user_name(num_id, bot))
      end
      # Replace channel IDs with names
      loop do
      match = /<#\d+>/.match(content)
      break if match.nil?
      # Get channel
      id = match[0]
      # We have to gsub to just get the numerical ID.
      num_id = /\d+/.match(id)[0]
      content = content.sub(id, get_channel_name(num_id, bot))
      end
      content
    end

    # Returns a user-readable username for the specified ID.
    def self.get_user_name(user_id, bot)
      to_return = nil
      begin
      to_return = '@' + bot.user(user_id).distinct
      rescue NoMethodError
      to_return = '@invalid-user'
      end
      to_return
    end

    # Returns a user-readable channel name for the specified ID.
    def self.get_channel_name(channel_id, bot)
      to_return = nil
      begin
      to_return = '#' + bot.channel(channel_id).name
      rescue NoMethodError
      to_return = '#deleted-channel'
      end
      to_return
    end

    def self.filter_everyone(text)
      text.gsub('@everyone', "@\x00everyone")
    end

    # Dumps all messages in a given channel.
    # Returns the filepath of the file containing the dump.
    def self.dump_channel(channel, output_channel = nil, folder, timestamp)
      server = if channel.private?
             'DMs'
           else
             channel.server.name
          end
      message = "Dumping messages from channel \"#{channel.name.gsub('`', '\\`')}\" in #{server.gsub('`', '\\`')}, please wait..."
      output_channel.send_message(message) unless output_channel.nil?
      puts message

      if !channel.private?
        output_filename = "#{folder}/output_" + server + '_' + channel.server.id.to_s + '_' + channel.name + '_' + channel.id.to_s + '_' + timestamp.to_s + '.txt'
      else
        output_filename = "#{folder}/output_" + server + '_' + channel.name + '_' + channel.id.to_s + '_' + timestamp.to_s + '.txt'
      end
      output_filename = output_filename.tr(' ', '_').delete('+').delete('\\').delete('/').delete(':').delete('*').delete('?').delete('"').delete('<').delete('>').delete('|')
      hist_count_and_messages = [[], [0, []]]

      output_file = File.open(output_filename, 'w')
      offset_id = channel.history(1, 1, 1)[0].id # get first message id

      # Now let's dump!
      loop do
        hist_count_and_messages[0] = channel.history(100, nil, offset_id) # next 100
        break if hist_count_and_messages[0] == []
        hist_count_and_messages[1] = parse_history(hist_count_and_messages[0], hist_count_and_messages[1][0])
        output_file.write((hist_count_and_messages[1][1].reverse.join("\n") + "\n").encode('UTF-8')) # write to file right away, don't store everything in memory
        output_file.flush # make sure it gets written to the file
        offset_id = hist_count_and_messages[0][0].id
      end
      output_file.close
      message = "#{hist_count_and_messages[1][0]} messages logged."
      output_channel.send_message(message) unless output_channel.nil?
      puts message
      puts "Done. Dump file: #{output_filename}"
      output_filename
    end

    def self.parse_history(hist, count)
      messages = []
      i = 0
      until i == hist.length
      message = hist[i]
      if message.nil?
        # STTTOOOOPPPPPP
        puts 'nii'
        break
      end
      author = if message.author.nil?
             'Unknown Disconnected User'
           else
             message.author.distinct
           end
      time = message.timestamp
      content = message.content

      attachments = message.attachments
      # attachments.each { |u| attachments.push("#{u.filename}: #{u.url}") }

      messages[i] = "--#{time} #{author}: #{content}"
      messages[i] += "\n<Attachments: #{attachments[0].filename}: #{attachments[0].url}}>" unless attachments.empty?
      #			puts "Logged message #{i} ID:#{message.id}: #{messages[i]}"
      i += 1

      count += 1
      end
      return_value = [count, messages]
      return_value
    end

    def self.role_from_name(server, rolename)
      roles = server.roles
      role = roles.select { |r| r.name == rolename }.first
      role
    end

    def self.get_help()
      help = "**__Using the bot__**\n"
      help << "\n"
      help << "**Adding codes:**\n"
      help << "`#{Config.prefix}code add wii | Wii Name | 1234-5678-9012-3456` (You can add multiple Wiis with different names)\n"
      help << "`#{Config.prefix}code add game | Game Name | 1234-5678-9012`\n"
      help << "\n"
      help << '**Editing codes**\n'
      help << "`#{Config.prefix}code edit wii | Wii Name | 1234-5678-9012-3456`\n"
      help << "`#{Config.prefix}code edit game | Game Name | 1234-5678-9012`\n"
      help << "\n"
      help << "**Removing codes**\n"
      help << "`#{Config.prefix}code remove wii | Wii Name`\n"
      help << "`#{Config.prefix}code remove game | Game Name`\n"
      help << "\n"
      help << "**Looking up codes**\n"
      help << "`#{Config.prefix}code lookup @user`\n"
      help << "\n"
      help << "**Adding a user's Wii**\n"
      help << "`#{Config.prefix}add @user`\n"
      help << "This will send you their codes, and then send them your Wii/game codes.\n"
      help
    end

    # Load settings for all.
    self.load_settings
  end
 end
