{ pkgs }:

(pkgs.callPackage ../php-mysql-site { }) {
  pname = "journalofdiscourses";
  rev = "ed9e8b02d8df9fa302319564577357a5880fef98";
  hash = "sha256-+EQl5dfizW5RXkO8fKlUSyZGLg3R1xkQS7gZqhAg/Ew=";
  sqlRev = "2a2f4684ebcbb9a659938d81bfba343ea0ee29af";
  sqlHash = "sha256-waAcap9yBX+q+GGvNdFRKQmiQhEG9wCgSNq2I6Y7q60=";
  envPrefix = "JOURNALOFDISCOURSES";
  phpNamespace = "JournalOfDiscourses";
  homepage = "https://gitlab.com/nocoolnametom/journalofdiscourses";
}
