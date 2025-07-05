const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
admin.initializeApp();

const gmailEmail = functions.config().smtp.email;
const gmailPassword = functions.config().smtp.password;

const mailTransport = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: gmailEmail,
    pass: gmailPassword,
  },
});

exports.sendScheduledEmailReminders = functions.pubsub
    .schedule("every 1 minutes")
    .onRun(async (context) => {
      const now = new Date();
      const remindersRef = admin.firestore().collection("emailReminders");
      const snapshot = await remindersRef
          .where("sent", "==", false)
          .where("reminderTime", "<=", now.toISOString())
          .get();

      const promises = [];
      snapshot.forEach((doc) => {
        const data = doc.data();
        const mailOptions = {
          from: gmailEmail,
          to: data.email,
          subject: `Assignment Reminder: ${data.assignmentTitle}`,
          text:
          `Your assignment "${data.assignmentTitle}" is due on ` +
          `${data.dueDate}. This is your reminder!`,
        };
        promises.push(
            mailTransport.sendMail(mailOptions).then(() => {
              return doc.ref.update({
                sent: true,
                sentAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            }),
        );
      });

      await Promise.all(promises);
      return null;
    });
