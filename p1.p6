my $lisaddr = '192.168.1.117';
my $remote = '192.168.1.1';
my $port    = 8000;
my $data;
my $conn;
try {
    $conn = IO::Socket::INET.new( :host('lll.com'),
                                 :port($port) );
    say "ooo";
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
        }
    }
}
say $conn.WHAT;
say "hello";
=begin comment
#sleep 2;
#try {
$conn.print: qq:to/END/;
GET / HTTP/1.1
Accept: text/html

END
while $data = $conn.recv {
    say $data;
}
$conn.close;
#}
=begin comment
CATCH {
    default {
        say .message;
    }
}
#=begin comment
await IO::Socket::Async.connect('192.168.1.117',$port).then(
   -> $conn {
       given $conn.result {
           .print: qq:to/END/;
                GET / HTTP/1.1
                Accept: text/html

                END
            react {
                whenever .Supply() -> $data {
                    $data.print;
                    done;
                }
            }

            .close;
       }
   } 
)
=end comment