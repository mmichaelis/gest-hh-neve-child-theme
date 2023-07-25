// Example of how to zip a directory 
var gulp = require('gulp');
var zip = require('gulp-zip');

gulp.task('zip', function () {
  return gulp.src([
    './**/*', 
    '!./{.*,.*/**/*}', 
    '!./{node_modules,node_modules/**/*}', 
    '!./assets/{sass,sass/*}', 
    '!./gulpfile.js', 
    '!./package.json', 
    '!./pnpm-lock.yaml',
    '!./*.zip',
  ])
    .pipe(zip('gest-hh-neve-child.zip'))
    .pipe(gulp.dest('./'));
});
