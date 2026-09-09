require 'json'
require 'net/http'

module DiscourseBaleNotifications
  class BaleNotifier
    def self.sendMessage(message)
      return self.doRequest('sendMessage', message)
    end

    def self.answerCallback(callback_id, text)
      message = {
        callback_query_id: callback_id,
        text: text
      }
      return self.doRequest('answerCallbackQuery', message)
    end

    def self.setupWebhook(key)
      message = {
        # آدرس وب‌هوک با دامنه بله و مسیر جدید
        url: Discourse.base_url + '/bale/hook/' + SiteSetting.bale_secret,
      }
      return self.doRequest('setWebhook', message)
    end

    def self.editKeyboard(message)
      return self.doRequest('editMessageReplyMarkup', message)
    end

    def self.doRequest(methodName, message)
      # تغییر دامنه به سرور بله
      http = Net::HTTP.new("tapi.bale.ai", 443)
      http.use_ssl = true
      
      access_token = SiteSetting.bale_access_token
      # تغییر Base URL به فرمت استاندارد بله
      uri = URI("https://tapi.bale.ai/bot#{access_token}/#{methodName}")
      
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = message.to_json
      
      response = http.request(req)
      responseData = JSON.parse(response.body)
      
      if not responseData['ok'] == true
        Rails.logger.error("Failed to send Bale message. Message data= " + req.body.to_json + " response=" + response.body.to_json)
        return false
      end
      return responseData
    end

    def self.generateReplyMarkup(post, user)
      likes = UserAction.where(action_type: UserAction::LIKE, user_id: user.id, target_post_id: post.id).count
      if likes > 0
        likeButtonText = I18n.t("discourse_bale_notifications.unlike")
        likeButtonAction = "unlike:#{post.id}"
      else
        likeButtonText = I18n.t("discourse_bale_notifications.like")
        likeButtonAction = "like:#{post.id}"
      end
      
      post_url = "#{Discourse.base_url}#{post.url(opts={without_slug: true})}"
      {
        inline_keyboard: [
          [
            { text: likeButtonText, callback_data: likeButtonAction },
            { text: I18n.t("discourse_bale_notifications.view_online"), url: post_url },
          ]
        ]
      }
    end
  end
end
