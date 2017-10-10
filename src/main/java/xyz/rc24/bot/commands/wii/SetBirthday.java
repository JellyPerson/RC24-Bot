package xyz.rc24.bot.commands.wii;

import com.google.cloud.datastore.Datastore;
import com.google.cloud.datastore.Entity;
import com.google.cloud.datastore.Key;
import com.jagrosh.jdautilities.commandclient.Command;
import com.jagrosh.jdautilities.commandclient.CommandEvent;
import net.dv8tion.jda.core.Permission;
import xyz.rc24.bot.commands.Categories;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

public class SetBirthday extends Command {
    private Datastore datastore;

    public SetBirthday(Datastore datastore) {
        this.datastore = datastore;
        this.name = "birthday";
        this.help = "Sets your birthday.";
        this.category = Categories.WII;
        this.botPermissions = new Permission[]{Permission.MESSAGE_WRITE};
    }

    @Override
    protected void execute(CommandEvent event) {
        try {
            // We only want the day and the month. We don't want the year, but
            // for user accessibility we'll leave it optional and never use it.
            DateTimeFormatter formatter = DateTimeFormatter.ofPattern("MM/dd[/yyyy]");
            LocalDate dateTime = LocalDate.parse(event.getArgs(), formatter);

            String userID = event.getAuthor().getId();

            Key taskKey = datastore.newKeyFactory().setKind("birthdays").newKey("birthdays");
            Entity entity = Entity.newBuilder(taskKey)
                    .set(userID, dateTime.getMonthValue() + "-" + dateTime.getDayOfMonth())
                    .build();
            datastore.put(entity);

            event.replySuccess("Updated successfully!");
        } catch (DateTimeParseException e) {
            e.printStackTrace();
            event.replyError("I couldn't parse your date.\n" +
                    "Due to a bug that I keep having, I require a year. Please don't give out your full birth year!\n" +
                    "Try something like: `" + event.getClient().getPrefix() + "birthday 04/20/1970` or some random year.");
        }
    }
}
