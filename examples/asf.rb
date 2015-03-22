#!/usr/bin/env ruby

require 'bundler/setup'
require 'gmail-britta'

if File.exist?(File.expand_path("~/.gmail-britta.personal.rb"))
  require "~/.gmail-britta.personal.rb"
else
  # Some fake constants to let you run this (-:
  MY_EMAILS = %w[test@example.com test.tester@example.com]
  FB_EMAIL = 'from:notification+ieanrst9@facebookemail.com'
  TWITTER_EMAILS = %w{n-yhex=abcdefg.def-3123f@postmaster.twitter.com}
  TWITTER_TEST_EMAILS = %w{n-yhex=abcdefg.def-12345@postmaster.twitter.com}
  BANK_EMAILS = %w{info@bankofamerica.com}
  V_EMAILS=['from:someone_important@example.com', {:or => MY_EMAILS.map{|email| "to:#{email}"}}]
  AMAZON_PACKAGE_TRACKING_EMAIL='amazon-package-tracker@example.com' # See https://github.com/antifuchs/amazon-autotracker
end


puts(GmailBritta.filterset(:me => MY_EMAILS) do
    # Put all mailman reminders away
    filter {
      has ['subject:"moderator request"']
      label 'bulk/mailman'
      smart_label 'notifications'
      archive
      mark_read
    }

    filter {
      has ['list:mailman@', 'subject:reminder']
      label 'bulk/mailman'
      smart_label 'notifications'
      archive
      mark_read
    }

    # Archive all mailman mail except confirmation ones
    filter {
      has %w{from:mailman subject:confirm}
      label 'bulk'
      smart_label 'notifications'
    }.otherwise {
      has %w{from:mailman}
      label 'bulk'
      smart_label 'notifications'
      archive
    }

    # Label all sysadmin-related email
    filter {
      has %w{to:root}
      archive
      label 'bulk/admin'
      smart_label 'notifications'
    }

    # Mailing lists I read:
    filter {
      has %w{list:mcclim-*@common-lisp.net}
      label 'lisp/McCLIM'
      smart_label 'forums'
    }.archive_unless_directed.otherwise {
      has [{:or => %w{list:*@common-lisp.net list:summeroflisp-discuss@lispnyc.org}}]
      label 'lisp'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has [{:or => %w{list:sbcl-devel list:sbcl-help}}]
      never_spam
      label 'lisp/sbcl'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has %w{list:cclan-list@lists.sourceforge.net}
      never_spam
      label 'lisp/cclan'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has %w{list:openmcl-*}
      label 'lisp/clozure'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has %w{list:quicklisp@googlegroups.com}
      label 'lisp/quicklisp'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has [{:or => %w{list:thingiverse@googlegroups.com list:replicatorg-dev@googlegroups.com}}]
      label 'thingiverse'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has %w{list:openscad@rocklinux.org}
      label 'thingiverse'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has %w{list:emacs-orgmode@gnu.org}
      label 'orgmode'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has %w{list:elixir-lang-core@googlegroups.com}
      label 'elixir'
      smart_label 'forums'
    }.archive_unless_directed

    filter {
      has [{:or => %w{list:discuss@lists.acemonstertoys.org list:amt-laserific@googlegroups.com
                      list:noisebridge-discuss@lists.noisebridge.net list:*@lists.metalab.at}}]
      label 'hackerspaces'
      smart_label 'forums'
    }.archive_unless_directed

    # Stuff from the bank:
    filter {
      has BANK_EMAILS
      label 'banking'
      mark_important
    }

    filter {
      has V_EMAILS
      label '=(-:<'
      mark_important
      never_spam
    }

    # People/things I get occasional personal email from:
    filter {
      has [{:or => %w{from:wakra@runtasia.at from:info@mordundmusik.at list:scw08@seedcamp.com list:startups@seedcamp.com}}]
      label 'bulk'
    }.archive_unless_directed

    filter {
      has %w{notifications@github.com}
      label 'open-source'
    }

    filter {
      has [FB_EMAIL, {:or => ['subject:"added you as a friend"', 'subject:"new messages from"', 'subject:"new message from"', 'subject:"changed the time"']}]
      label 'bulk/fb'
      smart_label 'social'
    }.otherwise {
      has [FB_EMAIL]
      label 'bulk/fb'
      smart_label 'social'
      archive
    }.otherwise {
      has TWITTER_EMAILS + [{:or => ['subject:"is now following"', 'subject:"direct message"']}]
      label 'bulk/twitter'
      smart_label 'social'
    }.otherwise {
      has [{:or => TWITTER_EMAILS + TWITTER_TEST_EMAILS}]
      label 'bulk/twitter'
      smart_label 'social'
      archive
      mark_read
    }.otherwise {
      # Mail from web services I don't care about THAT much:
      bacon_senders = %w{sender@mailer.33mail.com store-news@amazon.com thisweek@yelp.com no-reply@vimeo.com
        no-reply@mail.goodreads.com *@carsonified.com *@crossmediaweek.org updates@linkedin.com
        tordotcom@mail.macmillan.com noreply@myopenid.com tor-forge@mail.macmillan.com announce@mailer.evernote.com
        info@getsatisfaction.com Transport_for_London@info.tfl.gov.uk legendsofzork@joltonline.com news@xing.com
        noreply@couchsurfing.com noreply@couchsurfing.org newsletter@getsatisfaction.com store-offers@amazon.com
        gameware@letter.eyepin.com info@busymac.com engage@mail.communications.sun.com *@dotnetsolutions.co.uk
        office@runtasia.at noreply@cellulare.net support@heroku.com team@mixcloud.com automailer@wikidot.com
        no-reply@hi.im linkedin@em.linkedin.com chromium@googlecode.com
        noreply@comixology.com support@plancast.com *@*.boinx.com news@plug.at newsletter@gog.com service@youtube.com
        email@online.cvs.com info@mail.shoprunner.com yammer@yammer.com info@meetup.com}

      has [{:or => "from:(#{bacon_senders.join("|")})"}]
      archive
      label 'bulk'
      smart_label 'notifications'
    }.otherwise {
      to_me = me.map {|address| "to:#{address}"}
      has [{:or => to_me}]
      label '_asf'
    }

    filter {
      has [{:or => ['from:ship-confirm@amazon.com', 'from:auto-confirm@amazon.com', 'subject:"shipped"', '"tracking number"']}]
      label 'bulk/packages'
      smart_label 'notifications'
      forward_to AMAZON_PACKAGE_TRACKING_EMAIL
    }

  end.generate)
