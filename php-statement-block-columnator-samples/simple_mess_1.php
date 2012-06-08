    $record = fix_avatar($record);                                                                          
    $amount = $amount_formatter($record);                                                                   
    $title = h4(text($record->username) . (empty($record->title) ? "" : sprintf(" [%s]", $record->title)));
