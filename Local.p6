#local and remote conn info 
my $magic = "0x130E075\0";
my $hello = "Hello\0";
#remote info 
my @remote =  '175.24.31.138',20405;
#collect req
my $clireq = Channel.new;
#collect reply
my $servreply  = Channel.new;
#n connhosts
my $pthreadnum = 4;
#start
my $connpy = IO::Socket::Async.connect(|@remote);
await $connpy.then(-> $conn 
    { 
        my $connremote = $conn.result; 
        my $checkserv = 2;
        my @req[2];
        say "connect ",@remote.Str;
        for 1..$pthreadnum { start connhost; }
        react {
            whenever $connremote.Supply -> $buf {
                say $buf;
                if $buf ~~ /cli\: (.+) "\n"/ {
                    @req[0] = $/[0].Str;
                    @req[1] = $/.postmatch;
                    say 'ID:',@req[0];
                    say 'req',@req[1],"\n";
                    $clireq.send(@req);
                }
            }
            whenever $servreply -> $reply {
                say "Server response is:",$reply;
                $connremote.write($reply);
            }
        } 
        CATCH  {
            default { say .message; }
        }
    }
);

sub getid($id) {
    if $id ~~ /Host\: \s/ {
        my $host    = ($/.postmatch ~~ /\r\n/).prematch;
        if $host ~~ /\:/ {
            return $/.prematch, $/.postmatch.Int;
        }
        else {
            return $host,80;
        }
    }
}

sub connhost {
    my Str $ip;
    my Int $port;
    react {
        whenever $clireq -> @req {
            ($ip,$port) = getid(@req[1]);
            say "ip is $ip,port is $port";
            my $conn;
            try {
                my $time = now;
                $conn = IO::Socket::INET.new(:host($ip),:port($port));
                CATCH {
                    default {
                        say .message;
                        my $hosterror = qq:to/END/;
                        HTTP/1.1 505 Host Error
                        Content-Type: text/html; charset=UTF-8
                        Content-Encoding: UTF-8

                        <p>Host Error</p>
                        <p>{ .message }</p>
                        END
                        say $hosterror;
                        my $reply = Blob.new(@req[0].chars) ~ @req[0].encode ~ $hosterror.encode;
                        if now - $time < 2 { $servreply.send($reply); }
                    }
                }
            }
            if $conn {
                try {
                    my $time = now;
                    #say 'start print req';
                    #say @req[0];
                    $conn.print(@req[1]);
                    while my $reply = $conn.recv(:bin) {
						#sleep 1;
                        $reply = Blob.new(@req[0].chars) ~ @req[0].encode ~ $reply;
                        if now - $time < 2 { sleep 1 ;$servreply.send($reply); last; }
                    }
                    say "connect $ip:$port closed";
                    $conn.close;
                    CATCH {
                        default { say .message; }
                    }
                }
            }
        }
    }
}
