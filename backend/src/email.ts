export async function sendVerificationEmail(email: string, code: string): Promise<void> {
  // TODO: swap for a real provider (SendGrid, Resend, SMTP). Logging for now.
  console.log(`[email] Verification code for ${email}: ${code}`);
}
