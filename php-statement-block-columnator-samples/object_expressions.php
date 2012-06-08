$x = $y->call(10, 20, 30);
$x = $y->call(10, 20, 30)->call(40, 50, "string");
$x = $y->call("string", 20, 30)->call(40, "string", 60);