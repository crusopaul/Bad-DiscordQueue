Config = {
    PollDelayInSeconds = 5,
    GracePeriodInSeconds = 300, -- 5 min
    DeferralCardBufferInSeconds = 5,
    SplashImage = '',
    Displays = {
        Prefix = 'FiveM Server',
        Messages = {
            MSG_DETERMINING_PRIO = 'Your information has been located. Attempting to place you in queue.',
            MSG_DISCORD_REQUIRED = 'Your Discord ID was not detected. You are required to have Discord to play on this server.',
            MSG_DUPLICATE_LICENSE = 'Your Discord ID is already connected to this server.',
            MSG_MISSING_WHITELIST = 'Your Discord ID is not whitelisted.',
            MSG_PLACED_IN_QUEUE = 'You have been placed in queue with priority: %s.',
            MSG_QUEUE_PLACEMENT = 'You are in position %d / %d in queue.',
        },
    },
    Rankings = {
        -- LOWER NUMBER === HIGHER PRIORITY
        -- rolePriority should be between 0 and 10000
        ['Owner'] = 0,
        ['Admin'] = 1000,
        ['Dev Team'] = 2000,
        ['Staff'] = 3000,
        ['EMS'] = 6000,
        ['Police'] = 6000,
        ['Content Creator'] = 9500,
        ['Business Owners'] = 9500,
        ['Resident'] = 10000,
    },
}
