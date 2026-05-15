from string import Template

HEARING_REMINDER_HTML = Template("""
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; color: #333;">
  <div style="max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
    <h2 style="color: #1a5276;">Hearing Reminder</h2>
    <p>Dear <strong>${advocate_name}</strong>,</p>
    <p>This is a reminder for your upcoming hearing:</p>
    <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Case</strong></td>
          <td style="padding: 8px;">${case_number} — ${case_title}</td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Date</strong></td>
          <td style="padding: 8px;">${hearing_date}</td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Time</strong></td>
          <td style="padding: 8px;">${hearing_time}</td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Court Room</strong></td>
          <td style="padding: 8px;">${court_room}</td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Purpose</strong></td>
          <td style="padding: 8px;">${purpose}</td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Client</strong></td>
          <td style="padding: 8px;">${client_name}</td></tr>
    </table>
    <p style="color: #888; font-size: 12px;">Sent automatically by Legal CMS</p>
  </div>
</body>
</html>
""")

CASE_UPDATE_HTML = Template("""
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; color: #333;">
  <div style="max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
    <h2 style="color: #1a5276;">Case Status Update</h2>
    <p>Dear <strong>${advocate_name}</strong>,</p>
    <p>The status of case <strong>${case_number}</strong> has been updated.</p>
    <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Case</strong></td>
          <td style="padding: 8px;">${case_title}</td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>New Status</strong></td>
          <td style="padding: 8px; color: ${status_color};"><strong>${status}</strong></td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Client</strong></td>
          <td style="padding: 8px;">${client_name}</td></tr>
    </table>
    ${extra_info}
    <p style="color: #888; font-size: 12px;">Sent automatically by Legal CMS</p>
  </div>
</body>
</html>
""")

WELCOME_HTML = Template("""
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; color: #333;">
  <div style="max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
    <h2 style="color: #1a5276;">Welcome to Legal CMS</h2>
    <p>Dear <strong>${full_name}</strong>,</p>
    <p>Your account has been created successfully.</p>
    <table style="width: 100%; border-collapse: collapse; margin: 16px 0;">
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Email</strong></td>
          <td style="padding: 8px;">${email}</td></tr>
      <tr><td style="padding: 8px; background: #f0f0f0;"><strong>Bar Number</strong></td>
          <td style="padding: 8px;">${bar_number}</td></tr>
    </table>
    <p>You can now log in and start managing your cases, clients, and hearings.</p>
    <p style="color: #888; font-size: 12px;">Sent automatically by Legal CMS</p>
  </div>
</body>
</html>
""")
