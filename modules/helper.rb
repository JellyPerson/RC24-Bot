module SerieBot
  module Helper
    class << self
      attr_accessor :types
    end

    # Format:
    # [name, show_message]
    @types = {
        :owner => ['Dummy Entry', true],
        :dev => ['RiiConnect24 Developers', true],
        :bot => ['Bot Helpers', false],
        :mod => ['Server Moderators', true],
        :hlp => ['Helpers', false],
        :don => ['Donators', false],
        :adm => ['Server Admins', false],
        :trn => ['Translators', false]
    }

    # Gets the channel/role's ID based on the given parameters
    def self.get_xxx_id?(server_id, type, short_type)
      # Set all to defaults
      Config.settings[server_id] = {} if Config.settings[server_id].nil?
      Config.settings[server_id][type] = {} if Config.settings[server_id][type].nil?
      return Config.settings[server_id][type][short_type]
    end

    # Saves the role's ID based on the given parameters
    # e.g save_xxx_id?('srv', 'channel', event.server.id, id)
    # type can be channel, role, etc
    # short_name: mod, dev, srv, etc
    def self.save_xxx_id?(server_id, type, short_name, id)
      puts "Saving short type #{type} (type #{short_name}) with ID #{id} for server ID #{server_id}" if Config.debug
      # Potentially populate
      Config.settings[server_id] = {} if Config.settings[server_id].nil?
      Config.settings[server_id][type] = {} if Config.settings[server_id][type].nil?
      Config.settings[server_id][type][short_name] = id
      self.save_all
    end

    # Checks to see if the server has the needed channel, and if not deals accordingly to fix it.
    def self.get_xxx_channel?(event, short_type, channel_name)
      # Check if config already has a role
      xxx_channel_id = get_xxx_id?(event.server.id, 'channel', short_type)

      if xxx_channel_id.nil?
        # Set to default
        begin
          xxx_channel_id = channel_from_name(event.server, channel_name).id
          save_xxx_id?(event.server.id, 'channel', short_type, xxx_channel_id)
        rescue NoMethodError
          # Rip, we'll set the channel in config.
          # If we're debugging, might be helpful to say that.
          if Config.debug
            puts "I wasn't able to find the channel \"#{channel_name}\" for use with #{short_type}."
          end
          return nil
        end
        event.server.general_channel.send_message("Channel \"#{channel_name}\" set to default. Use `#{Config.prefix}config setchannel #{short_type} <channel name>` to change otherwise.")
      end

      # Check if the server has the specified channel
      return event.bot.channel(xxx_channel_id).id
    end

    # Checks to see if the user has the given role, and if not deals accordingly to fix it.
    def self.is_xxx_role?(event, role_type, full_name, show_message = true, other_user = nil)
      # Check if config already has a role
      xxx_role_id = get_xxx_id?(event.server.id, 'role', role_type)

      if xxx_role_id.nil?
        # Set to default
        begin
          xxx_role_id = role_from_name(event.server, full_name).id
          save_xxx_id?(event.server.id, 'role', role_type, xxx_role_id)
        rescue NoMethodError
          if show_message
            event.respond("I wasn't able to find the role \"#{full_name}\" for role-related tasks! See `#{Config.prefix}config help` for information.")
          end
          return false
        end
        event.respond("Role \"#{full_name}\" set to default. Use `#{Config.prefix}config setrole #{role_type} <role name>` to change otherwise.")
      end
      # Check if the member has the ID of said role
      user = other_user.nil? ? event.user : other_user
      return user.role?(event.server.role(xxx_role_id))
    end

    def self.has_role?(event, roles)
      # Only support listed types.
      roles.each do |role_type|
        if @types.include? role_type
          if role_type.to_s == 'owner'
            status = Config.bot_owners.include?(event.server.member(event.user))
          else
            role_info = @types[role_type]
            status = is_xxx_role?(event, role_type.to_s, role_info[0], role_info[1])
          end
          if status
            # They've got at least one of the roles
            puts "Looks like the user has #{role_type.to_s}" if Config.debug
            return status
          else
            # Continue, I guess
            next
          end
        else
          puts "I don't have the #{role_type.to_s} role in my list... perhaps you made a typo?" if Config.debug
        end
      end

      # If we got here we couldn't find the role
      puts 'The user had none of the roles requested!' if Config.debug
      return false
    end

    # We have to specify user here because we're checking if another user is verified
    def self.is_other_verified?(event, other_user = nil)
      user = other_user.nil? ? event.user : other_user
      return is_xxx_role?(event, 'vfd', 'Verified', true, user)
    end

    # TODO: perhaps save and stuff?
    def self.quit
      puts 'Exiting...'
      exit
    end

    def self.load_xyz(name, default_yaml = {:version=>1})
      folder = 'data'
      path_to_yml = "#{folder}/#{name}.yml"
      FileUtils.mkdir(folder) unless File.exist?(folder)
      unless File.exist?(path_to_yml)
        File.open(path_to_yml, 'w') { |file| file.write(default_yaml.to_yaml) }
      end
      return YAML.load(File.read(path_to_yml))
    end

    def self.save_xyz(name, location)
      File.open("data/#{name}.yml", 'w+') do |f|
        f.write(location.to_yaml)
      end
    end

    def self.load_all
      Morpher.messages = self.load_xyz('morpher') if Config.morpher_enabled
      Codes.codes = self.load_xyz('codes')
      Logging.recorded_actions = self.load_xyz('actions', {:ban => {}, :kick => {}, :warn => {}})
      Birthdays.dates = self.load_xyz('birthdays')
    end

    def self.save_all
      self.save_xyz('morpher', Morpher.messages)
      self.save_xyz('codes', Codes.codes)
      self.save_xyz('settings', Config.settings)
      self.save_xyz('birthdays', Birthdays.dates)
    end

    # We must keep this seperate due to how everything is loaded.
    def self.load_settings
      folder = 'data'
      settings_path = "#{folder}/settings.yml"
      FileUtils.mkdir(folder) unless File.exist?(folder)
      puts "[ERROR] I wasn't able to find data/settings.yml! Please grab the example from the repo." unless File.exist?(settings_path)
      Config.settings = YAML.load(File.read(settings_path))
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
      filename = filename.start_with?('a_') ? filename.gsub('.jpg', '.gif') : filename.gsub('.jpg', '.png')
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

      FileUtils.mkdir_p(folder) unless File.exist?(folder)
      FileUtils.rm(path) if File.exist?(path)

      File.new path, 'w'
      File.open(path, 'wb') do |file|
        file.write open(url).read
      end

      path
    end

    # If the user passed is a bot, it will be ignored.
    # Returns true if the user was a bot.
    def self.ignore_bots(event)
      if event.user.bot_account?
        id = event.user.id
        event.bot.ignore_user(id)
        # Add to persistent list
        Config.settings['ignored_bots'].push(id) unless Config.settings['ignored_bots'].include? id
        Helper.save_xyz('settings', Config.settings)
        true
      else
        false
      end
    end

    def self.upload_file(channel, filename)
      channel.send_file File.new([filename].sample)
    end

    # Accepts a message, and returns the message content, with all mentions + channels replaced with @user#1234 or #channel-name
    def self.parse_mentions(bot, content)
      # Replce user IDs with names
      loop do
        match = /<@\d+>/.match(content)
        break if match.nil?
        # Get user
        id = match[0]
        num_id = /\d+/.match(id)[0]
        content = content.sub(id, get_user_name(num_id, bot))
      end
      loop do
        match = /<@!\d+>/.match(content)
        break if match.nil?
        # Get user
        id = match[0]
        num_id = /\d+/.match(id)[0]
        content = content.sub(id, get_user_name(num_id, bot))
      end
      # Replace channel IDs with names
      loop do
        match = /<#\d+>/.match(content)
        break if match.nil?
        # Get channel
        id = match[0]
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
      server = channel.private? ? 'DMs' : channel.server.name
      message = "Dumping messages from channel \"#{channel.name.gsub('`', '\\`')}\" in #{server.gsub('`', '\\`')}, please wait...\n"
      output_channel.send_message(message) unless output_channel.nil?
      puts message

      unless channel.private?
        output_filename = "#{folder}/output_" + server + '_' + channel.server.id.to_s + '_' + channel.name + '_' + channel.id.to_s + '_' + timestamp.to_s + '.txt'
      else
        output_filename = "#{folder}/output_" + server + '_' + channel.name + '_' + channel.id.to_s + '_' + timestamp.to_s + '.txt'
      end
      output_filename = output_filename.tr(' ', '_').delete('+').delete('\\').delete('/').delete(':').delete('*').delete('?').delete('"').delete('<').delete('>').delete('|')

      output_file = File.open(output_filename, 'w')

      # Start on first message
      offset_id = channel.history(1, 1, 1)[0].id # get first message id
      message_count = 0

      # Now let's dump!
      loop do
        # We can only go through 100 messages at a time, so grab 100.
        current_history = channel.history(100, nil, offset_id).reverse
        # Break if there are no other messages
        break if current_history == []

        # Have a working string so we don't flog up disk writes
        to_write = ''
        current_history.each do |message|
          next if message.nil?
          author = message.author.nil? ? 'Unknown User' : message.author.distinct
          time = message.timestamp
          content = message.content

          attachments = message.attachments

          to_write += "#{time} #{author}: #{content}\n"
          to_write += "\n<Attachments: #{attachments[0].filename}: #{attachments[0].url}}>\n" unless attachments.empty?
          message_count += 1
        end

        output_file.write(to_write)
        output_file.flush

        # Set offset ID to last message in history that we saw
        # (this is the last message sent - 1 since Ruby has array offsets of 0)
        offset_id = current_history[current_history.length - 1].id
      end
      output_file.close
      message = "#{message_count} messages logged."
      output_channel.send_message(message) unless output_channel.nil?
      puts message
      puts "Done. Dump file: #{output_filename}"
      output_filename
    end

    def self.role_from_name(server, role_name)
      roles = server.roles
      role = roles.select { |r| r.name == role_name }.first
      return role
    end

    # Get the user's color
    def self.color_from_user(user, channel, default = 0)
      color = default
      return color if channel.private?

      # Attempt to grab member
      member = channel.server.member(user.id)
      unless member.nil?
        member.roles.sort_by(&:position).reverse.each do | role |
          next if role.color.combined == 0
          puts 'Using ' + role.name + '\'s color ' + role.color.combined.to_s if Config.debug
          color = role.color.combined
          break
        end
       end
      return color
    end

    def self.channel_from_name(server, channel_name)
      channels = server.channels
      if Config.debug
       puts "Looking for #{channel_name}"
      end
      channel = channels.select { |x| x.name == channel_name }.first
      puts "Found #{channel.name} (ID: #{channel.id})" if Config.debug
      return channel
    end

    def self.get_help
      help = "**__Using the bot__**\n"
      help += "\n"
      help += "**Adding codes:**\n"
      help += "`#{Config.prefix}code add wii | Wii Name Goes here | 1234-5678-9012-3456`\n"
      help += "`#{Config.prefix}code add game | Game Name | 1234-5678-9012`\n"
      help += "and many more types! Run `#{Config.prefix}code add` to see all supported code types right now, such as the 3DS and Switch.\n"
      help += "\n"
      help += "**Editing codes**\n"
      help += "`#{Config.prefix}code edit wii | Wii Name | 1234-5678-9012-3456`\n"
      help += "`#{Config.prefix}code edit game | Game Name | 1234-5678-9012`\n"
      help += "\n"
      help += "**Removing codes**\n"
      help += "`#{Config.prefix}code remove wii | Wii Name`\n"
      help += "`#{Config.prefix}code remove game | Game Name`\n"
      help += "\n"
      help += "**Looking up codes**\n"
      help += "`#{Config.prefix}code lookup @user`\n"
      help += "\n"
      help += "**Adding a user's Wii**\n"
      help += "`#{Config.prefix}add @user`\n"
      help += 'This will send you their codes, and then DM them your Wii/game codes.'
      return help
    end

    # Load settings for all.
    self.load_settings
  end
 end
