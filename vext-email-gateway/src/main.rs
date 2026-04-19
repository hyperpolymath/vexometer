// SPDX-License-Identifier: PMPL-1.0-or-later
// Vext Email Gateway - Production implementation
// Author: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

#![forbid(unsafe_code)]
mod types;

use lettre::{
    message::{header, Message as EmailMessage},
    transport::smtp::authentication::Credentials,
    SmtpTransport, Transport,
};
use mailparse::{parse_mail, MailHeaderMap};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{error, info, warn};
use std::collections::HashMap;
use types::*;

/// Email gateway configuration
#[derive(Debug, Clone)]
struct GatewayConfig {
    smtp_server: String,
    smtp_port: u16,
    smtp_username: String,
    smtp_password: String,

    // Mailing list domains
    list_domain: String,  // e.g., "lists.vext.org"

    // Rate limiting
    max_messages_per_day: usize,
    max_message_size: usize,
}

/// Subscription tracking
#[derive(Debug, Clone)]
struct Subscription {
    email: String,
    tags: Vec<String>,
    digest_mode: bool,  // true = daily digest, false = immediate
}

/// Email gateway state
struct Gateway {
    config: GatewayConfig,
    vext_network: Arc<dyn VextNetwork>,
    subscriptions: Arc<RwLock<HashMap<String, Subscription>>>,
    smtp_transport: SmtpTransport,
}

/// Trait for vext network operations (mockable for testing)
#[async_trait::async_trait]
trait VextNetwork: Send + Sync {
    async fn publish(&self, msg: Message) -> Result<()>;
    async fn query_tag(&self, tag: &str, limit: usize) -> Result<Vec<Message>>;
}

impl Gateway {
    fn new(config: GatewayConfig, vext_network: Arc<dyn VextNetwork>) -> Result<Self> {
        // Create SMTP transport
        let creds = Credentials::new(
            config.smtp_username.clone(),
            config.smtp_password.clone(),
        );

        let smtp_transport = SmtpTransport::relay(&config.smtp_server)
            .map_err(|e| VextError::InvalidEmail(e.to_string()))?
            .credentials(creds)
            .port(config.smtp_port)
            .build();

        Ok(Gateway {
            config,
            vext_network,
            subscriptions: Arc::new(RwLock::new(HashMap::new())),
            smtp_transport,
        })
    }

    /// Handle incoming email
    async fn handle_incoming_email(&self, raw_email: &[u8]) -> Result<()> {
        // Parse email
        let parsed = parse_mail(raw_email)
            .map_err(|e| VextError::InvalidEmail(e.to_string()))?;

        // Extract headers
        let from = parsed.headers.get_first_value("From")
            .ok_or_else(|| VextError::InvalidEmail("Missing From header".into()))?;

        let to = parsed.headers.get_first_value("To")
            .ok_or_else(|| VextError::InvalidEmail("Missing To header".into()))?;

        let subject = parsed.headers.get_first_value("Subject")
            .unwrap_or_default();

        // Extract body
        let body = parsed.get_body()
            .map_err(|e| VextError::InvalidEmail(e.to_string()))?;

        info!("Incoming email: from={}, to={}, subject={}", from, to, subject);

        // Route based on recipient
        if to.contains(&self.config.list_domain) {
            self.handle_list_post(&from, &to, &subject, &body).await?;
        } else if to.contains("subscribe@") {
            self.handle_subscription_command(&from, &subject).await?;
        } else {
            warn!("Unknown recipient: {}", to);
        }

        Ok(())
    }

    /// Handle post to mailing list
    async fn handle_list_post(
        &self,
        from: &str,
        to: &str,
        subject: &str,
        body: &str,
    ) -> Result<()> {
        // Extract tag from email address
        // e.g., journalism@lists.vext.org → "journalism"
        let tag = to.split('@')
            .next()
            .ok_or_else(|| VextError::InvalidEmail("Invalid list address".into()))?;

        info!("Posting to tag: {}", tag);

        // Create vext message
        // TODO: Get keypair from email-to-identity mapping
        let keypair = self.get_or_create_identity(from)?;

        let msg = Message::new(
            body.to_string(),
            &keypair,
            Some(subject.to_string()),
            vec![tag.to_string()],
        )?;

        // Verify message
        if !msg.verify()? {
            error!("Message verification failed!");
            return Err(VextError::InvalidSignature);
        }

        // Publish to vext network
        self.vext_network.publish(msg.clone()).await?;

        info!("Published message: {}", msg.id);

        // Send to mailing list subscribers
        self.send_to_subscribers(&msg, tag).await?;

        // Send confirmation to sender
        self.send_confirmation(from, &msg).await?;

        Ok(())
    }

    /// Handle subscription command
    async fn handle_subscription_command(&self, from: &str, subject: &str) -> Result<()> {
        // Parse command from subject
        // Examples:
        //   "SUBSCRIBE journalism"
        //   "UNSUBSCRIBE journalism"
        //   "DIGEST ON journalism"

        let parts: Vec<&str> = subject.split_whitespace().collect();

        match parts.as_slice() {
            ["SUBSCRIBE", tag] => {
                info!("Subscribing {} to {}", from, tag);

                let mut subs = self.subscriptions.write().await;
                subs.insert(from.to_string(), Subscription {
                    email: from.to_string(),
                    tags: vec![tag.to_string()],
                    digest_mode: false,
                });

                // Confirm
                self.send_simple_email(
                    from,
                    &format!("Subscribed to #{}", tag),
                    &format!("You are now subscribed to #{}.\n\nTo unsubscribe, email subscribe@vext.org with subject: UNSUBSCRIBE {}", tag, tag),
                ).await?;
            }

            ["UNSUBSCRIBE", tag] => {
                info!("Unsubscribing {} from {}", from, tag);

                let mut subs = self.subscriptions.write().await;
                subs.remove(from);

                // Confirm
                self.send_simple_email(
                    from,
                    &format!("Unsubscribed from #{}", tag),
                    "You have been unsubscribed.",
                ).await?;
            }

            _ => {
                warn!("Unknown subscription command: {}", subject);
                self.send_simple_email(
                    from,
                    "Unknown command",
                    "Commands:\n• SUBSCRIBE <tag>\n• UNSUBSCRIBE <tag>",
                ).await?;
            }
        }

        Ok(())
    }

    /// Send vext message to subscribers
    async fn send_to_subscribers(&self, msg: &Message, tag: &str) -> Result<()> {
        let subs = self.subscriptions.read().await;

        // Filter subscribers interested in this tag
        let interested: Vec<_> = subs.values()
            .filter(|sub| sub.tags.contains(&tag.to_string()) && !sub.digest_mode)
            .collect();

        info!("Sending to {} subscribers", interested.len());

        for sub in interested {
            if let Err(e) = self.send_message_email(&sub.email, msg).await {
                error!("Failed to send to {}: {}", sub.email, e);
            }
        }

        Ok(())
    }

    /// Send vext message as email
    async fn send_message_email(&self, to: &str, msg: &Message) -> Result<()> {
        let body = format!(
            "{}\n\n---\n\nAuthor: {}\nDate: {}\nTags: {}\n\nRead more: https://vext.org/messages/{}\nReply via email or web\n\nVerify signature: https://vext.org/verify/{}",
            msg.content,
            msg.author,
            msg.created,
            msg.tags.join(", "),
            msg.id,
            msg.id,
        );

        let from_addr = "Vext <noreply@vext.org>".parse()
            .expect("static literal 'Vext <noreply@vext.org>' is a valid mailbox");
        let to_addr = to.parse()
            .map_err(|e: lettre::address::AddressError| VextError::InvalidEmail(e.to_string()))?;
        let email = EmailMessage::builder()
            .from(from_addr)
            .to(to_addr)
            .subject(msg.title.clone().unwrap_or_else(|| "Vext message".to_string()))
            .header(header::ContentType::TEXT_PLAIN)
            .body(body)
            .map_err(|e| VextError::InvalidEmail(e.to_string()))?;

        self.smtp_transport.send(&email)
            .map_err(VextError::Email)?;

        Ok(())
    }

    /// Send simple text email
    async fn send_simple_email(&self, to: &str, subject: &str, body: &str) -> Result<()> {
        let from_addr = "Vext <noreply@vext.org>".parse()
            .expect("static literal 'Vext <noreply@vext.org>' is a valid mailbox");
        let to_addr = to.parse()
            .map_err(|e: lettre::address::AddressError| VextError::InvalidEmail(e.to_string()))?;
        let email = EmailMessage::builder()
            .from(from_addr)
            .to(to_addr)
            .subject(subject)
            .header(header::ContentType::TEXT_PLAIN)
            .body(body.to_string())
            .map_err(|e| VextError::InvalidEmail(e.to_string()))?;

        self.smtp_transport.send(&email)
            .map_err(VextError::Email)?;

        Ok(())
    }

    /// Send confirmation email
    async fn send_confirmation(&self, to: &str, msg: &Message) -> Result<()> {
        let body = format!(
            "Your message has been posted to the vext network!\n\nMessage ID: {}\nView online: https://vext.org/messages/{}\n\nIt will be distributed via:\n• NNTP (newsgroups)\n• Gemini protocol\n• Gopher protocol\n• Email (subscribers)\n• Web (https://vext.org)\n",
            msg.id,
            msg.id,
        );

        self.send_simple_email(to, "Message posted to vext", &body).await
    }

    /// Get or create cryptographic identity for email address
    fn get_or_create_identity(&self, _email: &str) -> Result<ed25519_dalek::SigningKey> {
        use rand::RngCore;

        // TODO: Persistent storage of email → keypair mapping
        // For now, generate a new signing key (INSECURE - prototype only).
        let mut rng = rand::rngs::OsRng;
        let mut sk = [0u8; 32];
        rng.fill_bytes(&mut sk);
        Ok(ed25519_dalek::SigningKey::from_bytes(&sk))
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    info!("Starting vext email gateway...");

    // Load configuration
    let config = GatewayConfig {
        smtp_server: std::env::var("SMTP_SERVER")
            .unwrap_or_else(|_| "smtp.example.com".to_string()),
        smtp_port: std::env::var("SMTP_PORT")
            .unwrap_or_else(|_| "587".to_string())
            .parse()
            .map_err(|e: std::num::ParseIntError| {
                VextError::Validation(format!("SMTP_PORT must be a valid u16: {}", e))
            })?,
        smtp_username: std::env::var("SMTP_USERNAME")
            .expect("SMTP_USERNAME required"),
        smtp_password: std::env::var("SMTP_PASSWORD")
            .expect("SMTP_PASSWORD required"),
        list_domain: "lists.vext.org".to_string(),
        max_messages_per_day: 100,
        max_message_size: 1_048_576, // 1MB
    };

    // TODO: Initialize vext network client
    // For now, use mock implementation
    struct MockVextNetwork;

    #[async_trait::async_trait]
    impl VextNetwork for MockVextNetwork {
        async fn publish(&self, msg: Message) -> Result<()> {
            info!("Publishing to vext network: {}", msg.id);
            Ok(())
        }

        async fn query_tag(&self, tag: &str, limit: usize) -> Result<Vec<Message>> {
            info!("Querying tag: {} (limit: {})", tag, limit);
            Ok(vec![])
        }
    }

    let vext_network = Arc::new(MockVextNetwork);

    // Create gateway
    let _gateway = Gateway::new(config, vext_network)?;

    info!("Email gateway ready!");

    // TODO: Listen for incoming emails (SMTP server or poll IMAP)
    // For now, just keep running
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(60)).await;
    }
}

#[cfg(test)]
mod tests {
    #[tokio::test]
    async fn test_email_to_vext_message() {
        // TODO: Test email parsing and conversion to vext message
    }

    #[tokio::test]
    async fn test_subscription_management() {
        // TODO: Test subscribe/unsubscribe
    }

    #[tokio::test]
    async fn test_rate_limiting() {
        // TODO: Test rate limits enforced
    }
}
