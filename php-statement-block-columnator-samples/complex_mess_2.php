$rewards = Class::method( $object )                          or $service->respond_database_unavailable();
$manager->check_item_exists( $item_code )           or $service->respond_failure("That item code doesn't exist." );
!$manager->check_item_out_of_stock( $item_code )      or $service->respond_failure("That item is out of stock.");
!$manager->check_item_expired( $item_code )           or $service->respond_failure("That item is expired.");
!$manager->check_item_already_redeemed( $item_code, $player->user_id )  or $service->respond_failure("You've already used that item.");

