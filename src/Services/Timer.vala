/* Timer.vala
 *
 * Copyright 2022-2023 Diego Iván <diegoivan.mae@gmail.com>
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Flowtime.Services.Timer : Object {
    public bool running { get; protected set; default = false; }

    private int _seconds;
    public int seconds {
        get {
            return _seconds;
        }
        set {
            _seconds = value;
            formatted_time = format_time ();
            updated ();
        }
    }

    public bool is_used {
        get {
            return running || seconds > 0;
        }
    }

    public TimerMode mode { get; private set; default = WORK; }
    public string formatted_time { get; private set; }

    public signal void updated ();
    public signal void done ();

    private const int INTERVAL_MILLISECONDS = 1000;
    private uint? timeout_id = null;

    private DateTime? last_datetime = null;
    private int initial_breaktime = 0;

    ~Timer () {
        stop ();
        save_to_statistics ();
    }

    construct {
        seconds = 0;
    }

    public void start () {
        last_datetime = new DateTime.now_utc ();
        running = true;
        timeout_id = Timeout.add (INTERVAL_MILLISECONDS, timeout);
    }

    public void stop () {
        running = false;
        if (timeout_id == null) {
            return;
        }
        Source.remove (timeout_id);
    }

    public void next_mode () {
        stop ();
        last_datetime = null;
        save_to_statistics ();

        var settings = new Settings ();

        /*
         * This would mean that we want to change the mode to break. We will obtain the seconds for this
         * mode and change it accordingly
         */
        if (mode == WORK) {
            initial_breaktime = (int) (seconds * settings.break_percentage / 100);
            seconds = initial_breaktime;
            mode = BREAK;
        }
        else {
            // Reset timer in case the next mode is work mode
            seconds = 0;
            initial_breaktime = 0;
            mode = WORK;
        }

        if (settings.autostart) {
            start ();
        }
    }

    private string format_time () {
        return "%02d:%02d".printf (seconds / 60, seconds % 60);
    }

    public void save_to_statistics () {
        var statistics = new Statistics ();
        if (mode == WORK) {
            statistics.add_time_to_mode (mode, seconds);
        }
        else {
            statistics.add_time_to_mode (mode, initial_breaktime - seconds);
        }
    }

    protected bool timeout () {
        if (!running) {
            return false;
        }

        var current_time = new DateTime.now_utc ();

        if (last_datetime == null) {
            last_datetime = current_time;
        }

        // Obtaining the difference between the last and current times, casting it to seconds
        int time_seconds = (int) (current_time.difference (last_datetime) / TimeSpan.SECOND);

        switch (mode) {
            case WORK:
                seconds += time_seconds;
                break;

            case BREAK:
                if (time_seconds >= seconds) {
                    seconds = 0;
                    done ();
                    next_mode ();
                    return false;
                }
                else {
                    seconds -= time_seconds;
                }
                break;

            default:
                assert_not_reached ();
        }
        last_datetime = current_time;

        return true;
    }
}

public enum Flowtime.Services.TimerMode {
    WORK,
    BREAK;

    public string to_string () {
        switch (this) {
            case WORK:
                return _("Work");
            case BREAK:
                return _("Break");
            default:
                assert_not_reached ();
        }
    }
}
