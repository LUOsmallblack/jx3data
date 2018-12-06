<?php
# https://stackoverflow.com/questions/2071024/treating-warnings-as-errors
function exception_error_handler($errno, $errstr, $errfile, $errline ) {
  throw new ErrorException($errstr, $errno, 0, $errfile, $errline);
}
set_error_handler("exception_error_handler");

# http://php.net/manual/zh/tidy.examples.basic.php
ob_start();
require($argv[1]);
$html = ob_get_clean();

$tidy_options = array('indent' => true, 'wrap' => 0);
$tidy = new Tidy();
$tidy->parseString($html, $tidy_options);
$tidy->cleanRepair();
echo $tidy . "\n";
?>
