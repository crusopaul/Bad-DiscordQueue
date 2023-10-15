create table if not exists queueStats (
    id int auto_increment,
    discordId varchar(255),
    queueStartTime datetime,
    queueStopTime datetime,
    primary key (id)
);

/*
 * -- See breakdown by queue type for the past 7 days
 * select
 *     queueType as 'Queue Type',
 *     avg(timestampdiff(
 *         second,
 *         queueStartTime,
 *         queueStopTime
 *     )) as 'Queue Time Average (s)',
 *     stddev(timestampdiff(
 *         second,
 *         queueStartTime,
 *         queueStopTime
 *     )) as 'Queue Time Std. Dev. (s)',
 *     min(timestampdiff(
 *         second,
 *         queueStartTime,
 *         queueStopTime
 *     )) as 'Queue Min (s)',
 *     max(timestampdiff(
 *         second,
 *         queueStartTime,
 *         queueStopTime
 *     )) as 'Queue Max (s)',
 *     count(1) as 'Count'
 * from queueStats
 * where
 *     ifnull(queueStartTime, '12/31/9999') <> '12/31/9999'
 *     and timestampdiff(day, queueStartTime, now()) <= 7
 * group by
 *     queueType
 * order by
 *     2 desc,
 *     3 desc,
 *     Count desc,
 *     'Queue Type';
 */
