module DiscourseNarrativeBot
  class TrackSelector
    include Actions

    GENERIC_REPLIEX_COUNT_PREFIX = 'discourse-narrative-bot:track-selector-count:'.freeze

    TRACKS = [
      NewUserNarrative
    ]

    def initialize(input, user, post)
      @input = input
      @user = user
      @post = post
    end

    def select
      if @post
        topic_id = @post.topic_id

        TRACKS.each do |klass|
          track = klass.new
          data = track.get_data(@user)

          if selected_track(klass::RESET_TRIGGER)
            track.reset_bot(@user, @post)
            return
          elsif (data && data[:topic_id] == topic_id)
            track.input(@input, @user, @post)
            return
          end
        end

        if bot_mentioned?(@post) || (@input == :reply && pm_to_bot?(@post))
          mention_replies
        elsif reply_to_bot_post?(@post)
          generic_replies
        end
      end
    end

    private

    def selected_track(trigger)
      bot_mentioned?(@post) && @post.raw.match(/#{trigger}/)
    end

    def mention_replies
      post_raw = @post.raw

      raw =
        if match_data = post_raw.match(/roll (\d+)d(\d+)/i)
          I18n.t(i18n_key('random_mention.dice'),
            results: Dice.new(match_data[1].to_i, match_data[2].to_i).roll.join(", ")
          )
        elsif match_data = post_raw.match(/show me a quote/i)
          I18n.t(i18n_key('random_mention.quote'), QuoteGenerator.generate)
        else
          I18n.t(
            i18n_key('random_mention.message'),
            discobot_username: self.class.discobot_user.username,
            new_user_track: NewUserNarrative::RESET_TRIGGER
          )
        end

      fake_delay

      reply_to(@post, raw)
    end

    def generic_replies
      key = "#{GENERIC_REPLIEX_COUNT_PREFIX}#{@user.id}"
      count = ($redis.get(key) || $redis.setex(key, 900, 0)).to_i

      case count
      when 0
        reply_to(@post, I18n.t(i18n_key('do_not_understand.first_response'),
          reset_trigger: NewUserNarrative::RESET_TRIGGER,
          discobot_username: self.class.discobot_user.username
        ))
      when 1
        reply_to(@post, I18n.t(i18n_key('do_not_understand.second_response'),
            reset_trigger: NewUserNarrative::RESET_TRIGGER,
            discobot_username: self.class.discobot_user.username
        ))
      else
        # Stay out of the user's way
      end

      $redis.incr(key)
    end

    def i18n_key(key)
      "discourse_narrative_bot.track_selector.#{key}"
    end
  end
end
