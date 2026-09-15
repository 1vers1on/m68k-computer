package com.ellie.programmer;

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
    }
}
