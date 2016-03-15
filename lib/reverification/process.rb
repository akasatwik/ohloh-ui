module Reverification
  class Process
    class << self
      def ses
        @ses ||= AWS::SimpleEmailService.new
      end

      def sqs
        @sqs ||= AWS::SQS.new
      end

      def success_queue
        @success_queue ||= sqs.queues.named('ses-success-queue')
      end

      def bounce_queue
        @bounce_queue ||= sqs.queues.named('ses-bounces-queue')
      end

      def complaints_queue
        @complaints_queue ||= sqs.queues.named('ses-complaints-queue')
      end

      def ses_limit_reached?
        quotas = ses.quotas
        quotas[:sent_last_24_hours] == quotas[:max_24_hour_send]
      end

      # rubocop:disable Metrics/AbcSize
      def bounce_limit_reached?
        emails_sent_yesterday = ses.statistics.find_all do |stats|
          stats[:sent].to_date == Time.now.utc.to_date - 1.day
        end
        number_of_bounces = emails_sent_yesterday.count { |emails| emails[:bounces] > 0 }.to_f
        ((number_of_bounces / emails_sent_yesterday.count) * 100) < 5.00
      end
      # rubocop:enable Metrics/AbcSize

      def ses_daily_limit_available
        quotas = ses.quotas
        quotas[:max_24_hour_send] - quotas[:sent_last_24_hours]
      end

      def send_email(template, account, phase)
        resp = ses.send_email(template)
        if account.reverification_tracker
          update_tracker(account.reverification_tracker, phase, resp)
        else
          account.create_reverification_tracker(message_id: resp[:message_id], sent_at: Time.now.utc)
        end
      end

      def poll_success_queue
        success_queue.poll(initial_timeout: 1, idle_timeout: 1) do |msg|
          message_hash = msg.as_sns_message.body_message_as_h
          message_hash['delivery']['recipients'].each do |recipient|
            account = Account.find_by_email recipient
            account.reverification_tracker.delivered! if account.reverification_tracker.pending?
          end
        end
      end

      def poll_bounce_queue
        bounce_queue.poll(initial_timeout: 1, idle_timeout: 1) do |msg|
          decoded_msg = msg.as_sns_message.body_message_as_h
          decoded_msg['bounce']['bouncedRecipients'].each do |recipient|
            handle_bounce_notification(decoded_msg['bounce']['bounceType'], recipient['emailAddress'])
          end
        end
      end

      def poll_complaints_queue
        complaints_queue.poll(initial_timeout: 1, idle_timeout: 1) do |msg|
          decoded_msg = msg.as_sns_message.body_message_as_h
          decoded_msg['complaint']['complainedRecipients'].each do |recipient|
            rev_tracker = Account.find_by_email(recipient['emailAddress']).reverification_tracker
            rev_tracker.complained!
            rev_tracker.update feedback: decoded_msg['complaint']['complaintFeedbackType']
          end
        end
      end

      def start_polling_queues
        poll_success_queue
        poll_bounce_queue
        poll_complaints_queue
      end

      def cleanup
        ReverificationTracker.remove_reverification_trackers_for_verifed_accounts
        ReverificationTracker.delete_expired_accounts
      end

      def handle_bounce_notification(type, recipient)
        rev_tracker = Account.find_by_email(recipient).reverification_tracker
        case type
        when 'Permanent' then ReverificationTracker.destroy_account(recipient)
        when 'Transient', 'Undetermined' then rev_tracker.soft_bounced!
        end
      end

      def update_tracker(rev_tracker, phase, response)
        if phase == rev_tracker.phase_value
          rev_tracker.increment! :attempts
        else
          rev_tracker.update attempts: 1
        end
        rev_tracker.update(message_id: response[:message_id], status: 0, phase: phase, sent_at: Time.now.utc)
      end
    end
  end
end
