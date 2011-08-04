#
# Fluent
#
# Copyright (C) 2011 FURUHASHI Sadayuki
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
module Fluent
module Logger


class SyslogLogger < TextLogger
  def initialize(ident=$0, level=:info)
    super()
    require 'syslog'

    @ident = ident
    self.level = level
    #self.facility = facility
    Syslog.open(@ident)
  end

  attr_reader :level

  def level=(level)
    level = level.to_sym if level.is_a?(String)
    @level = case level
      when :emerg, Syslog::LOG_EMERG
        Syslog::LOG_EMERG
      when :alert, Syslog::LOG_ALERT
        Syslog::LOG_ALERT
      when :crit, Syslog::LOG_CRIT
        Syslog::LOG_CRIT
      when :err, :error, Syslog::LOG_ERR
        Syslog::LOG_ERR
      when :warning, :warn, Syslog::LOG_WARNING
        Syslog::LOG_WARNING
      when :notice, Syslog::LOG_NOTICE
        Syslog::LOG_NOTICE
      when :info, Syslog::LOG_INFO
        Syslog::LOG_INFO
      when :debug, Syslog::LOG_DEBUG
        Syslog::LOG_DEBUG
      else
        raise "Unknown level description #{level.inspect}"
      end
  end

  #def facility=(facility)
  #  facility = facility.to_sym if facility.is_a?(String)
  #  @facility = case facility
  #    when :auth, Syslog::LOG_AUTH
  #      Syslog::LOG_AUTH
  #    when :authpriv, Syslog::LOG_AUTHPRIV
  #      Syslog::LOG_AUTHPRIV
  #    when :console, Syslog::LOG_CONSOLE
  #      Syslog::LOG_CONSOLE
  #    when :cron, Syslog::LOG_CRON
  #      Syslog::LOG_CRON
  #    when :daemon, Syslog::LOG_DAEMON
  #      Syslog::LOG_DAEMON
  #    when :ftp, Syslog::LOG_FTP
  #      Syslog::LOG_FTP
  #    when :kern, Syslog::LOG_KERN
  #      Syslog::LOG_KERN
  #    when :lpr, Syslog::LOG_LPR
  #      Syslog::LOG_LPR
  #    when :mail, Syslog::LOG_MAIL
  #      Syslog::LOG_MAIL
  #    when :news, Syslog::LOG_NEWS
  #      Syslog::LOG_NEWS
  #    when :ntp, Syslog::LOG_NTP
  #      Syslog::LOG_NTP
  #    when :security, Syslog::LOG_SECURITY
  #      Syslog::LOG_SECURITY
  #    when :syslog, Syslog::LOG_SYSLOG
  #      Syslog::LOG_SYSLOG
  #    when :user, Syslog::LOG_USER
  #      Syslog::LOG_USER
  #    when :uucp, Syslog::LOG_UUCP
  #      Syslog::LOG_UUCP
  #    when :local0, Syslog::LOG_LOCAL0
  #      Syslog::LOG_LOCAL0
  #    when :local1, Syslog::LOG_LOCAL1
  #      Syslog::LOG_LOCAL1
  #    when :local2, Syslog::LOG_LOCAL2
  #      Syslog::LOG_LOCAL2
  #    when :local3, Syslog::LOG_LOCAL3
  #      Syslog::LOG_LOCAL3
  #    when :local4, Syslog::LOG_LOCAL4
  #      Syslog::LOG_LOCAL4
  #    when :local5, Syslog::LOG_LOCAL5
  #      Syslog::LOG_LOCAL5
  #    when :local6, Syslog::LOG_LOCAL6
  #      Syslog::LOG_LOCAL6
  #    when :local7, Syslog::LOG_LOCAL7
  #      Syslog::LOG_LOCAL7
  #    else
  #      raise "Unknown facility description #{facility.inspect}"
  #    end
  #  Syslog.reopen(@ident, Syslog::LOG_PID|Syslog::LOG_CONS, @facility)
  #  facility
  #end

  def post_text(text)
    Syslog.log(@level, text)
  end

  def close
    Syslog.close
    self
  end

  register_logger :syslog
end


end
end
