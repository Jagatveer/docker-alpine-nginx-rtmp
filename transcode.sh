#!/bin/sh

on_die ()
{
    (date; echo "stream over") >>/tmp/mytv.log;
    pkill -KILL -P $WHILE_PID
    pkill -KILL -P $$
}

trap 'on_die' TERM
(date; echo "stream start") >>/tmp/mytv.log;

date > /tmp/s3-$1.log

date >/tmp/ffmpeg-mytv-$1.log;

ffmpeg -v verbose -i rtmp://localhost/mytv/$1 \
-c:v libx264 -c:a aac -b:v 1216k -b:a 128k -vf "scale=480:trunc(ow/a/2)*2" \
-tune zerolatency -preset veryfast -crf 23 -profile:v baseline -flags -global_header \
-hls_time 10 -hls_list_size 7 -hls_flags delete_segments -hls_wrap 7 /tmp/hls/test-max.m3u8 \
-c:v libx264 -c:a aac -b:v 704k -b:a 128k -vf "scale=360:trunc(ow/a/2)*2" \
-tune zerolatency -preset veryfast -crf 23 -profile:v baseline -flags -global_header \
-hls_time 10 -hls_list_size 7 -hls_flags delete_segments -hls_wrap 7 /tmp/hls/test-med.m3u8 \
-c:v libx264 -c:a aac -b:v 576k -b:a 64k -vf "scale=240:trunc(ow/a/2)*2" \
-tune zerolatency -preset veryfast -crf 23 -profile:v baseline -flags -global_header \
-hls_time 10 -hls_list_size 7 -hls_flags delete_segments -hls_wrap 7 /tmp/hls/test-low.m3u8 \
-c:v libx264 -c:a aac -b:v 135k -b:a 32k -vf "scale=144:trunc(ow/a/2)*2" \
-tune zerolatency -preset veryfast -crf 23 -profile:v baseline -flags -global_header \
-hls_time 10 -hls_list_size 7 -hls_flags delete_segments -hls_wrap 7 /tmp/hls/test-min.m3u8 &>>/tmp/ffmpeg-mytv-$1.log &

export AWS_ACCESS_KEY_ID=$key
export AWS_SECRET_ACCESS_KEY=$secret
export AWS_DEFAULT_REGION=$region

echo $AWS_DEFAULT_REGION >>/tmp/mytv.log

(inotifywait -m -e CLOSE_WRITE /tmp/hls/*.ts | while read file action
 do
  echo "file: $file">>/tmp/s3-$1.log
  sname="s3://ptc-dev"`echo $file | sed "s/tmp\///"`
  /usr/local/bin/aws s3 cp $file $sname
  if [[ "$file" == *"min"* ]]
  then
        /usr/local/bin/aws s3 cp /tmp/hls/$1-min.m3u8 s3://ptc-dev/hls/$1-min.m3u8
  else
        /usr/local/bin/aws s3 cp /tmp/hls/$1-max.m3u8 s3://ptc-dev/hls/$1-max.m3u8
  fi
 done) &>>/tmp/s3-$1.log &

WHILE_PID=$!
wait
