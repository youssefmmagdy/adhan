const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { google } = require('googleapis');

admin.initializeApp();

exports.scheduleAzan = functions.firestore
    .document('azans/{dayId}')
    .onCreate(async (snapshot, context) => {
        const prayerTimes = snapshot.data();

        const prayers = [
            { name:  "shurouq", time: prayerTimes.shurouq },
            { name:  "fajr", time: prayerTimes.fajr },
            { name:  "zuhr", time: prayerTimes.zuhr },
            { name:  "asr", time: prayerTimes.asr },
            { name:  "maghrib", time: prayerTimes.maghrib },
            { name:  "ishaa", time: prayerTimes.ishaa },
        ];

        const projectId = 'azan-e10a5';  // Replace with your project ID
        const location = 'us-central1';  // Replace with your region
        const serviceAccount = require('./serviceAccountKey.json');  // Replace with your service account file

        // Authenticate with Google Cloud
        const auth = new google.auth.GoogleAuth({
            credentials: serviceAccount,
            scopes: ['https://www.googleapis.com/auth/cloud-platform'],
        });

        const cloudScheduler = google.cloudscheduler({
            version: 'v1',
            auth: auth
        });

        const now = new Date();
        now.setHours(now.getHours() + 3); // Adjust to your timezone (e.g., UTC+3)
        console.log('Current time: ', now);
        for (let prayer of prayers) {
            if (!prayer.time) {
                console.error(`Time is missing for ${prayer.name}`);
                continue;  // Skip to the next iteration if time is missing
            } 
            console.log(`Checking ${prayer.name} prayer time...`);
            const [hours, minutes] = prayer.time.split(':').map(Number);
            const prayerDate = new Date();
            prayerDate.setHours(prayerDate.getHours() + 3); // Adjust to your timezone (e.g., UTC+3)
            console.log("prayer date is "+prayerDate);
            prayerDate.setHours(hours, minutes, 0, 0);
            console.log("prayer date is "+prayerDate);

            const delayInMilliseconds = prayerDate - now;
            console.log(`${prayer.name} prayer time: ${prayerDate}`);
            console.log(`Delay in milliseconds: ${delayInMilliseconds}`);
            if (delayInMilliseconds > 0) {
                // Schedule the task with Cloud Scheduler
                const scheduleTime = new Date(now.getTime() + delayInMilliseconds);
                const cronExpression = `${scheduleTime.getUTCMinutes()} ${scheduleTime.getUTCHours()} ${scheduleTime.getUTCDate()} ${scheduleTime.getUTCMonth() + 1} *`;

                const jobName = `projects/${projectId}/locations/${location}/jobs/${prayer.name}-azan-job`;


                console.log(`Scheduling ${prayer.name} notification for ${scheduleTime}`);
                const request = {
                    parent: `projects/${projectId}/locations/${location}`,
                    resource: {
                        name: jobName,
                        schedule: cronExpression,  // When to trigger
                        timeZone: 'Africa/Cairo',  // Adjust for your timezone
                        httpTarget: {
                            uri: `https://us-central1-${projectId}.cloudfunctions.net/sendAzanNotification`,
                            httpMethod: 'POST',
                            body: Buffer.from(JSON.stringify({
                                prayer: prayer.name,
                                message: `It's time for ${prayer.name} prayer.`,
                            })).toString('base64'),
                            headers: { 'Content-Type': 'application/json' },
                        }
                    }
                };
                
                try {
                    // Check if the job exists
                    await cloudScheduler.projects.locations.jobs.get({ name: jobName });
                    console.log(`Job ${jobName} exists. Deleting it...`);
            
                    // Delete the job if it exists
                    await cloudScheduler.projects.locations.jobs.delete({ name: jobName });
                    console.log(`Job ${jobName} deleted.`);
                } catch (error) {
                    if (error.code === 404) {
                        console.log(`Job ${jobName} does not exist. Proceeding to create a new job.`);
                    } else {
                        console.error('Error checking job existence:', error);
                        return;
                    }
                }
            
                try {
                    // Create the new job
                    const response = await cloudScheduler.projects.locations.jobs.create(request);
                    console.log(`${prayer.name} notification scheduled for ${prayer.time}`);
                    console.log('Response:', response);
                } catch (error) {
                    console.error('Error scheduling job:', error);
                }
                
            }
        }
    });


// Function that will handle the actual sending of the notification
exports.sendAzanNotification = functions.https.onRequest(async (req, res) => {
    const { prayer, message } = req.body;

    console.log('Received request to send notification:', req.body);

    try {
        await admin.messaging().send({
            notification: {
                title: `${prayer} Prayer Reminder`,
                body: message,
            },
            topic: 'azan-notifications',
        });
        res.status(200).send(`Notification for ${prayer} sent successfully.`);
    } catch (error) {
        console.error('Error sending notification:', error);
        res.status(500).send('Error sending notification');
    }
});

