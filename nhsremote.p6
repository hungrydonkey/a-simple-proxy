#conn and close info 
my $conninfo  = Channel.new;
my $closeinfo = Channel.new;

#collect eche cli's req
my $senddata  = Channel.new;

#distribute data to eche cli
my $recvdata  = Supplier.new;

#prompt info
my \localnotconn = qq:to/END/;
HTTP/1.1 503 Local Not Connect
Content-Type: text/html; charset=UTF-8
Content-Encoding: UTF-8

<P>Local Not Connect
<p>Please retry!</p>
END

#listen socket info
my @liscli     = '0.0.0.0',50610;
my @lislocal   = '0.0.0.0',20405;

#listen
my $conncli   = IO::Socket::Async.listen(|@liscli);
my $connlocal = IO::Socket::Async.listen(|@lislocal);
say "listen on port:@liscli[1] for cli";
say "listen on port:@lislocal[1] for local";
#local conn 
my $servavail = False;

sub putconninfo {
    react {
        whenever $conninfo -> @info {
            say  'new client connect:';
            say  "peer host is @info[0]";
            say  "peer port is @info[1]\n";
        }
    }
}

sub putcloseinfo {
    react {
        whenever $closeinfo -> $info {
            say  "$info\n";
        }
    }
}
sub slipdata($data) {
    my $id    = Blob.new($data[1 .. $data[0]]).decode;
    my $reply = Blob.new($data[($data[0]+1) .. *]);
    return $id,$reply;
}
#=begin comment
sub processdata($local) {
    say 'start process data';
    say "local is $servavail";
    react {
        whenever $senddata -> @req {
            my $req = 'cli:' ~ @req[0] ~ "\n" ~ @req[1];
            say $req;
            $local.print($req);
        }
        whenever $local.Supply(:bin) -> $reply {
            say $reply;
            $recvdata.emit($reply);
        }
    }
}
#=end comment
#local and remote conn info 
my $magic = "0x130E075\0";
my $hello = "Hello\0";

sub localman {
    react {
        whenever $connlocal -> $local {
            my @localinfo = $local.peer-host,':',$local.peer-port;
            my $start     = Supplier.new;
            my $checkcli = $start.Supply;
            my $check     = '';
            say |@localinfo, ' local has connected.';
            $servavail = True;
            start processdata($local);
        }
    }
}
#main here
react {
    start localman;
    start putconninfo;
    start putcloseinfo;
    say $servavail;
    whenever $conncli -> $cli {
        start {
            my @peerinfo = $cli.peer-host, $cli.peer-port;
            $conninfo.send(@peerinfo);
            if $servavail != True {
                $cli.print(localnotconn);
                $cli.close;
                $closeinfo.send('server closed ' ~ $cli.peer-host ~ ':' ~ $cli.peer-port);
            }
            else {
                try {
                    react {
                        whenever $cli.Supply -> $httpreq {
                            if $httpreq ~~ /HTTP/ {
                                $senddata.send((@peerinfo,$httpreq));
                            }
                            #done;
                        }
                        whenever $recvdata.Supply -> $data {
                                my ($id,$reply) = slipdata($data);
                                say "id:$id";
                                if @peerinfo.Str eq $id {
                                    $cli.write($reply);
                                }
                        }
                        whenever Supply.interval(1,5) {
                            done;
                        }
                    }
                    $cli.close;
                    $closeinfo.send('server closed ' ~ $cli.peer-host ~ ':' ~ $cli.peer-port); 
                    CATCH   {
                        default { say |@peerinfo ~ .message; }
                    }           
                }
            }

        }
    }
}
