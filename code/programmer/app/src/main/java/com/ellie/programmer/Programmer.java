package com.ellie.programmer;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.help.HelpFormatter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class Programmer {
    private Programmer() {}

    public static final Logger logger = LoggerFactory.getLogger(Programmer.class);

    private static volatile Programmer instance;
    public static final Object instanceLock = new Object();

    public static Programmer getInstance() {
        if (instance == null) {
            synchronized (instanceLock) {
                if (instance == null) {
                    logger.debug("Creating new instance of Programmer");
                    instance = new Programmer();
                }
            }
        }

        return instance;
    }

    public void run(String[] args) throws Exception {
        logger.debug("Running Programmer with arguments: {}", (Object) args);

        setupCommandLineOptions(args);
    }

    private void setupCommandLineOptions(String[] args) throws Exception {
        Options options = new Options();
        options.addOption("h", "help", false, "Show help");

        CommandLineParser parser = new DefaultParser();
        CommandLine cmd = parser.parse(options, args);

        if (cmd.hasOption("h")) {
            HelpFormatter formatter = HelpFormatter.builder().setShowSince(false).get();
            formatter.printHelp("programmer", null, options, null, true);
            stop(0);
        }
    }

    public void stop(int exitCode) {
        logger.debug("Stopping Programmer with exit code: {}", exitCode);
        System.exit(exitCode);
    }
}
