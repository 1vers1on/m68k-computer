package com.ellie.programmer;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public final class Main {
    private Main() {}

    private static final Logger logger = LoggerFactory.getLogger(Main.class);

    public static void main(String[] args) {
        Thread.setDefaultUncaughtExceptionHandler(
                (thread, error) -> logger.error("Uncaught exception on thread '{}'", thread.getName(), error));

        logger.debug(
                "Runtime details: javaVersion={}, vmName={}, osName={}, osArch={}, processors={}, argumentCount={}",
                System.getProperty("java.version"),
                System.getProperty("java.vm.name"),
                System.getProperty("os.name"),
                System.getProperty("os.arch"),
                Runtime.getRuntime().availableProcessors(),
                args == null ? 0 : args.length);

        try {
            Programmer programmer = Programmer.getInstance();
            programmer.run(args);
            logger.debug("Programmer run completed successfully");
        } catch (Throwable t) {
            logger.error("Fatal error on the main thread", t);
            System.exit(1);
        }
    }
}
