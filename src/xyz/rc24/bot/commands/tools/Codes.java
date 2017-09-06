package xyz.rc24.bot.commands.tools;

/*
 * The MIT License
 *
 * Copyright 2017 Artu.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */


import com.jagrosh.jdautilities.commandclient.Command;
import com.jagrosh.jdautilities.commandclient.CommandEvent;
import com.jagrosh.jdautilities.utils.FinderUtil;
import net.dv8tion.jda.core.EmbedBuilder;
import net.dv8tion.jda.core.Permission;
import net.dv8tion.jda.core.entities.ChannelType;
import net.dv8tion.jda.core.entities.Member;
import xyz.rc24.bot.utils.GlobalUtil;

import java.awt.*;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Manages codes for the user, stored in the yaml format.
 *
 * @author Spotlight
 */

public class Codes extends Command {
    private Map<String, Map<String, Map<String, String>>> codes;

    public Codes(Map codes) {
        this.codes = codes;
        this.name = "code";
        this.help = "Manages codes for the user.";
        this.children = new Command[]{new Add(), new Remove(), new Edit(), new Lookup(), new Help()};
        this.category = new Command.Category("Wii-related");
        this.botPermissions = new Permission[]{Permission.MESSAGE_WRITE};
        this.guildOnly = false;
    }

    @Override
    protected void execute(CommandEvent event) {
        event.replyError("Please enter a valid option for the command.\n" +
                "Valid options: `add`, `edit`, `remove`, `lookup`, `help`.");
    }

    private class Lookup extends Command {
        Lookup() {
            this.name = "lookup";
            this.help = "Displays codes for the user.";
            this.category = new Command.Category("Wii-related");
            this.botPermissions = new Permission[]{Permission.MESSAGE_WRITE, Permission.MESSAGE_EMBED_LINKS};
        }

        @Override
        protected void execute(CommandEvent event) {
            Member member;
            if (event.getArgs().isEmpty()) {
                member = event.getMember();
            } else {
                List<Member> potentialMembers = FinderUtil.findMembers(event.getArgs(), event.getGuild());
                if (potentialMembers.isEmpty()) {
                    event.replyError("I couldn't find a user by that name!");
                    return;
                } else {
                    member = potentialMembers.get(0);
                }
            }
            // If there wasn't a user found, just halt execution.
            if (member == null) {
                event.replyError("I couldn't find that user!");
                return;
            }
            EmbedBuilder codeEmbed = new EmbedBuilder();
            // Set a default color for non-role usage.
            Color embedColor = Color.decode("#0083e2");
            if (!(event.getChannelType() == ChannelType.PRIVATE)) {
                embedColor = member.getColor();
            }
            codeEmbed.setColor(embedColor);
            codeEmbed.setAuthor("Profile for " + member.getEffectiveName(),
                    null, member.getUser().getEffectiveAvatarUrl());

            // I promise you, it's a map.
            Map<String, Map<String, String>> userCodes = codes.get(event.getAuthor().getId());
            if (userCodes == null || userCodes.isEmpty()) {
                event.replyError("**" + event.getMember().getEffectiveName() + "** has not added any friend codes!");
                return;
            }
            for (Map.Entry<String, Map<String, String>> typeData : userCodes.entrySet()) {
                // We define each code as the name (key) and the code (value) itself.
                Map<String, String> codes = typeData.getValue();
                // Make sure it's not null or empty and such
                if (codes != null && !codes.isEmpty()) {
                    StringBuilder fieldContents = new StringBuilder();
                    for (Map.Entry<String, String> codeData : codes.entrySet()) {
                        // Add in the format `nameOfCode`:
                        //                   value
                        fieldContents.append("`").append(codeData.getKey()).append("`:\n")
                                .append(codeData.getValue()).append("\n");
                    }
                    // Now that we have the code text set up, we'll just add it as a field.
                    codeEmbed.addField(codeTypes.get(typeData.getKey()), fieldContents.toString(), true);
                }
                // I guess all codes for it were deleted if we got here.
                // Carry on!
            }

            event.reply(codeEmbed.build());
        }
    }

    private class Add extends Command {
        Add() {
            this.name = "add";
            this.help = "Adds codes for the user.";
            this.category = new Command.Category("Wii-related");
            this.botPermissions = new Permission[]{Permission.MESSAGE_WRITE, Permission.MESSAGE_EMBED_LINKS};
        }

        @Override
        protected void execute(CommandEvent event) {
            String type = event.getArgs().split(" ")[0];
            if (!codeTypes.containsKey(type)) {
                event.replyError(getTypes());
            }

            String id = event.getAuthor().getId();
            Map<String, Map<String, String>> userCodes = codes.get(id);
            if (userCodes == null) {
                // Populate it!
                codes.put(event.getAuthor().getId(), new HashMap<>());
                userCodes = codes.get(event.getAuthor().getId());
            }
            Map<String, String> typeCodes = userCodes.get(type);

            // Begin the parsing.
            String toAdd = event.getArgs().substring(type.length());
            // For example, we might have | Name | code
            // We need to determine the name and code.
            String[] information = toAdd.split(" \\| ");
            // [0] is name, [1] is code
            String errorMessage = "Hm, I couldn't parse that.\nThe correct format is " +
                    "`" + event.getClient().getPrefix() + "code add " + type + " | name | code`.";
            if (information[0].equals(toAdd)) {
                event.replyError(errorMessage);
                return;
            }
            if (information[0].isEmpty() || information[1].isEmpty()) {
                event.replyError(errorMessage);
            }
            typeCodes.put(information[0], information[1]);
            userCodes.put(type, typeCodes);
            codes.put(id, userCodes);
            GlobalUtil.saveData("codes", codes);
        }
    }

    private class Remove extends Command {
        Remove() {
            this.name = "remove";
            this.help = "Removes codes for the user.";
            this.category = new Command.Category("Wii-related");
            this.botPermissions = new Permission[]{Permission.MESSAGE_WRITE, Permission.MESSAGE_EMBED_LINKS};
        }

        @Override
        protected void execute(CommandEvent event) {
            event.replySuccess("Stub!");
        }
    }

    private class Edit extends Command {
        Edit() {
            this.name = "edit";
            this.help = "Edits codes for the user.";
            this.category = new Command.Category("Wii-related");
            this.botPermissions = new Permission[]{Permission.MESSAGE_WRITE, Permission.MESSAGE_EMBED_LINKS};
        }

        @Override
        protected void execute(CommandEvent event) {
            event.replySuccess("Stub!");
        }
    }

    private class Help extends Command {
        Help() {
            this.name = "help";
            this.help = "Shows help regarding codes.";
            this.category = new Command.Category("Wii-related");
            this.botPermissions = new Permission[]{Permission.MESSAGE_WRITE, Permission.MESSAGE_EMBED_LINKS};
        }

        @Override
        protected void execute(CommandEvent event) {
            String help = "**__Using the bot__**\n\n" +
                    "**Adding codes:**\n" +
                    "`" + event.getClient().getPrefix() + "code add wii | Wii Name Goes here | 1234-5678-9012-3456`\n" +
                    "`" + event.getClient().getPrefix() + "code add game | Game Name | 1234-5678-9012`\n" +
                    "and many more types! Run `" + event.getClient().getPrefix() + "code add` " +
                    "to see all supported code types right now, such as the 3DS and Switch.\n\n" +
                    "**Editing codes**\n" +
                    "`" + event.getClient().getPrefix() + "code edit wii | Wii Name | 1234-5678-9012-3456`\n" +
                    "`" + event.getClient().getPrefix() + "code edit game | Game Name | 1234-5678-9012`\n" +
                    "\n" +
                    "**Removing codes**\n" +
                    "`" + event.getClient().getPrefix() + "code remove wii | Wii Name`\n" +
                    "`" + event.getClient().getPrefix() + "code remove game | Game Name`\n" +
                    "\n" +
                    "**Looking up codes**\n" +
                    "`" + event.getClient().getPrefix() + "code lookup @user`\n" +
                    "\n" +
                    "**Adding a user's Wii**\n" +
                    "`" + event.getClient().getPrefix() + "add @user`\n" +
                    "This will send you their codes, and then DM them your Wii/game codes.";
            event.reply(help);
        }
    }


    private static final Map<String, String> codeTypes = new HashMap<String, String>() {{
        put("wii", "<:Wii:259081748007223296> **Wii**");
        put("3ds", "<:New3DSXL:287651327763283968> **3DS**");
        put("nnid", "<:NintendoNetworkID:287655797104836608> **Nintendo Network ID**");
        put("switch", "<:Switch:287652338791874560> **Switch**");
        put("game", "🎮 **Games**");
    }};

    private static final Map<String, String> badgeTypes = new HashMap<String, String>() {{
        put("owner", "<:BadgeBotDev:331597705472114688>");
        put("dev", "<:BadgeDeveloper:338399284376633367>");
        put("adm", "<:BadgeAdmin:338398740727726081>");
        put("mod", "<:BadgeModerator:329715070768513024>");
        put("hlp", "<:BadgeHelper:338399338739007488>");
        put("don", "<:BadgeDonator:329712167983251458>");
        put("trn", "<:BadgeTranslator:329723303814234113>");
    }};

    private String getTypes() {
        StringBuilder response = new StringBuilder("Invalid type! Valid types:\n");
        for (String type : codeTypes.keySet()) {
            response.append("`").append(type).append("`, ");
        }
        // Remove leftover comma + space
        return response.substring(0, response.length() - 2);
    }
}