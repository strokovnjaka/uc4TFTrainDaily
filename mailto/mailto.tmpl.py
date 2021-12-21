import smtplib
import ssl

# use the below or define your own


def mail_results(subject, message):
    port = 465
    smtp_server = "smtp.gmail.com"
    sender_mail = "<enter your dummy test gmail>"
    recipient_mails = ["<enter recipient1 mail>"]
    content = f"Dear Madam/Sir,\n\n{message}\n\nYours truly,\nBugs Bunny"
    password = "<enter your dummy test gmail password>"

    ssl_context = ssl.create_default_context()
    service = smtplib.SMTP_SSL(smtp_server, port, context=ssl_context)
    service.login(sender_mail, password)
    result = service.sendmail(sender_mail, recipient_mails, f"Subject: {subject}\n{content}")
    service.quit()
