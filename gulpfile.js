// Example of how to zip a directory
var gulp = require("gulp");
var zip = require("gulp-zip");

gulp.task("zip", function () {
  return gulp
    .src(["./theme/**/*"])
    .pipe(zip("gest-hh-neve-child.zip"))
    .pipe(gulp.dest("./"));
});
