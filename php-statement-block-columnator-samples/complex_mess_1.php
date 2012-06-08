$conversions = Class1::method_x($cache) or $service->respond_database_unavailable(); $x = 12;
$names = Class2::method_y($cache) or $service->respond_database_unavailable();
$from_something != $to_something or $service->respond_failure("\"from\" and \"to\" something must be different");
$amount > 0 or $service->respond_failure("Amount must be positive");
$from_something_name = @$names[$from_something] or $service->respond_failure("Unrecognized \"from\" something $from_something");
$to_something_name = @$names[$to_something] or $service->respond_failure("Unrecognized \"to\" something $to_something");
array_key_exists($from_something, $conversions) or $service->respond_failure("Conversion not supported");
array_key_exists($to_something, $conversions[$from_something]->rates) or $service->respond_failure("Conversion not supported");
$amount <= $player->$from_something_name or $service->respond_failure("You don't have enough $from_something_name");
$x = new DateTime();
$y = new DateTime;


