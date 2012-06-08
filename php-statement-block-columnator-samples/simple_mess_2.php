$this->board_query = $board_query;
$this->limit = $limit;
$this->format_string = is_array($format_strings) ? implode("<br>\n", $format_strings) : $format_strings;
$this->highest_to_lowest = $highest_to_lowest;
