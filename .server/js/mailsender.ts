import nodemailer from "nodemailer";
import { reportError } from "./errorHandler";
require('dotenv').config();

//don't even try mate these aren't real codes lol
//const transporter = nodemailer.createTransport({
//  host: "smtp.mailgun.org",
//  port: 587,
//  secure: false,
//  auth: {
//    user: 'postmaster@noreply.platerates.com',
//    pass: '15fbe28a1a0ee074fcd02e751b18365e-b7b36bc2-268b9f45'
//  }
//});


const transporter = nodemailer.createTransport({
  //I have got no clue why typescript doesn't like this lmao
  //spent like 3 days switching back to javascript then back this so I give up lol it is what it is
  // @ts-ignore
  host: process.env.MailHost,
  port: process.env.MailPort,
  secure: process.env.MailAuthUser == "true",
  auth: {
    user: process.env.MailAuthUser,
    pass: process.env.MailAuthPass
  }
});

// async..await is not allowed in global scope, must use a wrapper
async function sendMail(from : string,to : string,subject : string,text : string) {
    try{
        // send mail with defined transport object
        const info: nodemailer.SentMessageInfo = await transporter.sendMail({
          from: from, // sender address
          to: to, // list of receivers
          subject: subject, // Subject line
          text: text, // plain text body
        });

        console.log("Message sent: %s", info.messageId);
        return info;
    }catch (err){
        reportError(err);
        return null
    }
}

export {
  sendMail,
};