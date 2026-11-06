package aemu.su;

import android.system.Os;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public final class Main {
    private static final String VERSION = "AEmulator UID shim 1.1.0 (not Magisk)";

    public static void main(String[] args) throws Exception {
        if (args.length == 1 && ("--version".equals(args[0]) || "-v".equals(args[0]))) {
            System.out.println(VERSION);
            return;
        }

        if (args.length == 1 && ("--help".equals(args[0]) || "-h".equals(args[0]))) {
            System.out.println("Usage: su [-v] | su -c COMMAND | su [COMMAND [ARG...]]");
            return;
        }

        Os.setgid(0);
        Os.setuid(0);

        final List<String> command = new ArrayList<>();
        command.add("/system/bin/sh");
        if (args.length == 0) {
            command.add("-i");
        } else if ("-c".equals(args[0])) {
            command.add("-c");
            command.add(args.length > 1 ? args[1] : "");
        } else {
            command.addAll(Arrays.asList(args));
        }

        ProcessBuilder builder = new ProcessBuilder(command);
        builder.inheritIO();
        System.exit(builder.start().waitFor());
    }
}
