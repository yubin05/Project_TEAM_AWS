/**
 * Lambda: mediaconvert-trigger
 *
 * 트리거: S3 ObjectCreated (source-videos/{hotelId}/original.mp4)
 * 역할:   MediaConvert 변환 잡 생성 (MP4 → HLS 1080p/720p/480p)
 *
 * 필요 환경변수:
 *   MEDIACONVERT_ENDPOINT   예) https://xxxx.mediaconvert.ap-northeast-2.amazonaws.com
 *   MEDIACONVERT_ROLE_ARN   예) arn:aws:iam::123456789:role/MediaConvertRole
 *   S3_OUTPUT_BUCKET        예) my-output-videos-bucket
 *   AWS_REGION              예) ap-northeast-2
 *
 * 필요 IAM 권한 (Lambda 실행 역할):
 *   mediaconvert:CreateJob
 *   s3:GetObject  (source bucket)
 *   s3:PutObject  (output bucket)
 *   iam:PassRole  (MediaConvert 역할)
 */

const {
  MediaConvertClient,
  CreateJobCommand,
} = require('@aws-sdk/client-mediaconvert');

const ENDPOINT    = process.env.MEDIACONVERT_ENDPOINT;
const ROLE_ARN    = process.env.MEDIACONVERT_ROLE_ARN;
const OUT_BUCKET  = process.env.S3_OUTPUT_BUCKET;
const REGION      = process.env.AWS_REGION || 'ap-northeast-2';

const client = new MediaConvertClient({
  region:   REGION,
  endpoint: ENDPOINT,
});

exports.handler = async (event) => {
  for (const record of event.Records) {
    const srcBucket = record.s3.bucket.name;
    const srcKey    = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));

    // source-videos/{hotelId}/original.mp4
    const parts   = srcKey.split('/');
    const hotelId = parts[1];

    const inputUri  = `s3://${srcBucket}/${srcKey}`;
    const outputUri = `s3://${OUT_BUCKET}/output-videos/${hotelId}/`;

    const jobSettings = {
      Role: ROLE_ARN,
      Settings: {
        Inputs: [{
          FileInput: inputUri,
          AudioSelectors: { 'Audio Selector 1': { DefaultSelection: 'DEFAULT' } },
          VideoSelector: {},
          TimecodeSource: 'ZEROBASED',
        }],
        OutputGroups: [{
          Name: 'HLS Group',
          OutputGroupSettings: {
            Type: 'HLS_GROUP_SETTINGS',
            HlsGroupSettings: {
              Destination:      outputUri,
              SegmentLength:    6,
              MinSegmentLength: 0,
            },
          },
          Outputs: [
            makeHlsOutput('1080p', 1920, 1080, 5000000, 192000),
            makeHlsOutput('720p',  1280,  720, 2500000, 128000),
            makeHlsOutput('480p',   854,  480, 1000000,  96000),
          ],
        }],
      },
      UserMetadata: { hotelId },
    };

    try {
      const res = await client.send(new CreateJobCommand(jobSettings));
      console.log(`MediaConvert Job created: ${res.Job.Id} for hotel ${hotelId}`);
    } catch (err) {
      console.error('MediaConvert job creation failed:', err);
      throw err;
    }
  }
};

function makeHlsOutput(suffix, width, height, videoBitrate, audioBitrate) {
  return {
    NameModifier: `_${suffix}`,
    ContainerSettings: { Container: 'M3U8' },
    VideoDescription: {
      Width:  width,
      Height: height,
      CodecSettings: {
        Codec: 'H_264',
        H264Settings: {
          Bitrate:           videoBitrate,
          RateControlMode:   'CBR',
          CodecProfile:      'HIGH',
          CodecLevel:        'AUTO',
          FramerateControl:  'INITIALIZE_FROM_SOURCE',
          GopSize:           90,
          GopSizeUnits:      'FRAMES',
          InterlaceMode:     'PROGRESSIVE',
          ScanTypeConversionMode: 'INTERLACED',
        },
      },
    },
    AudioDescriptions: [{
      CodecSettings: {
        Codec: 'AAC',
        AacSettings: {
          Bitrate:        audioBitrate,
          CodingMode:     'CODING_MODE_2_0',
          SampleRate:     48000,
        },
      },
    }],
  };
}
