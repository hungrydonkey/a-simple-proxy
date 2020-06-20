#local and remote conn info 
my $magic = "0x130E075\0";
my $hello = "Hello\0";
#remote info 
my @remote =  '127.0.0.1',20405;
#collect req
my $clireq = Channel.new;
#collect reply
my $servreply  = Channel.new;
#n connhosts
my $pthreadnum = 2;
#start
my $connpy = IO::Socket::Async.connect(|@remote);
await $connpy.then(-> $conn 
    { 
        my $connremote = $conn.result; 
        my $checkserv = 2;
        my @req[2];
        for 1..$pthreadnum { start connhost; }
        $connremote.print($hello);
        react {
            whenever $connremote.Supply -> $buf {
                given $buf {
                    say $buf;
                    when $hello {
                        if $checkserv == 2 {
                            $connremote.print($magic);
                            $checkserv -= 1;
                        }
                        else { die "repeat"; }
                    }
                    when "Oh! Magic.\0" {
                        if $checkserv == 1 { done; }
                        else { die "serv error"; }
                    }
                    default {
                        say "no way!";
                        $connremote.close;
                        die "serv error";
                    }
                }
            }
        }    
        react {
            whenever $connremote.Supply -> $buf {
                say $buf;
                if $buf ~~ /(.+) "\n"/ {
                    @req[0] = $/[0].Str;
                    @req[1] = $/.postmatch;
                }
                say 'req0:',@req[0];
                say 'req1:',@req[1];
                $clireq.send(@req);
            }
            whenever $servreply -> $reply {
                #say $reply.WHAT,$reply.elems;
                $connremote.write($reply);
                say 'send!!!!';
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
                        if now - $time < 5 { $servreply.send($reply); }
                    }
                }
            }
            if $conn {
                try {
                    my $time = now;
                    say 'start print req';
                    say @req[0];
                    $conn.print(@req[1]);
                    while my $reply = $conn.recv(:bin) {
                        $reply = Blob.new(@req[0].chars) ~ @req[0].encode ~ $reply;
                        if now - $time < 5 { $servreply.send($reply); }
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
