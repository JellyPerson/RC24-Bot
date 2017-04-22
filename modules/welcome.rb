module SerieBot
  module Welcome
    # Commands and events
    extend Discordrb::Commands::CommandContainer
    extend Discordrb::EventContainer

    member_join do |event|
      riiconnect_server_id = if Config.debug
                                # SpotConnect24
                                301840988744450048
                              else
                                # RiiConnect24
                                206934458954153984
                              end

      id = event.server.id
      # RC24 News Server
      if id == 278674706377211915
        message_to_pm = "___Information Notice___\n"
        message_to_pm += 'Hi! You have joined the RiiConnect24 News Server, for users who are not allowed access to the regular server.'
        message_to_pm += "As such, we do not know whom is in the server, and you may wish to turn off access to Direct Messages between members to ensure users cannot contact you through the public mutual server.\n"
        message_to_pm += "Here's how to do it: http://i.imgur.com/EssBp8d.gifv\n\n"
        message_to_pm += "Regards,\nRiiConnect24"
        event.user.pm(message_to_pm)
      elsif id == riiconnect_server_id
        # Find the welcome channel.
        # I'm not even gonna do any checks as this should work no matter what.
        welcome_channel_id = Helper.channel_from_name(event.server, 'welcome')
        welcome_channel_id.send_message("👋 Welcome, #{event.user.mention}, to the **RiiConnect24** Server! " +
                                                                           'Check your DMs with me (the bot)! I\'ll get you verified.')
        verify(event)
      end
    end

    command(:verify) do |event|
      # Should only be run in #welcome.
      unless event.channel.id == @welcome_channel_id
        verify(event)
      end
    end

    def self.verify(event)
      welcome_channel_id = Helper.channel_from_name(event.server, 'welcome')
      begin
        event.user.pm("Welcome to RiiConnect24! I'm RiiConnect24 Bot, the official bot. I have a few questions before I can verify you to access the rest of the server. Don't worry, they're easy!")
        event.user.pm("How'd you find out about RiiConnect24? (e.g by Google, YouTube, forum post, etc)")
        # I'm so sorry for the following chain reaction. -Spotlight
        event.user.pm.await(:find_out_dm, from: event.user.id) do |event|
          # Will this actually work? Find out tomorrow.
          # TODO: do something with this
          reason = event.message.content
          puts reason
        end
      rescue Discordrb::Errors::NoPermission
        welcome_channel_id.send_message("❌ Uh uh, looks like you're blocking DMs. Allow server DMs from me, and run `!verify` to start this again.")
      end
    end
  end
end