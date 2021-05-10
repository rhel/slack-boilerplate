package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strconv"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/arn"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/kinesis"
)

func SlackErrorResponse(text string) map[string]string {
	return map[string]string{
		"response_type": "ephemeral",
		"text":          fmt.Sprintf("ERROR: %s", text),
	}
}

func SupportCommand(params []string) (events.APIGatewayProxyResponse, error) {
	command := params[0]
	kinesisArn := params[1]
	targetShardCount, err := strconv.ParseInt(params[2], 10, 64)
	if err != nil {
		body, _ := json.Marshal(SlackErrorResponse(err.Error()))
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(body),
		}, nil
	}

	switch command {
	case "change-shard":
		break
	default:
		body, _ := json.Marshal(SlackErrorResponse(fmt.Sprintf("'%s' is not a valid command.", command)))
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(body),
		}, nil
	}

	if !arn.IsARN(kinesisArn) {
		body, _ := json.Marshal(SlackErrorResponse(fmt.Sprintf("'%s' is not a valid ARN.", kinesisArn)))
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(body),
		}, nil
	}

	s := session.New()
	kc := kinesis.New(s)

	streamName := kinesisArn[strings.LastIndex(kinesisArn, "/")+1:]
	summary, err := kc.DescribeStreamSummary(&kinesis.DescribeStreamSummaryInput{
		StreamName: aws.String(streamName),
	})
	if err != nil {
		body, _ := json.Marshal(SlackErrorResponse(err.Error()))
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(body),
		}, nil
	}
	fmt.Printf("%v\n", summary)

	_, err = kc.UpdateShardCount(&kinesis.UpdateShardCountInput{
		ScalingType:      aws.String("UNIFORM_SCALING"),
		StreamName:       aws.String(streamName),
		TargetShardCount: aws.Int64(targetShardCount),
	})
	if err != nil {
		body, _ := json.Marshal(SlackErrorResponse(err.Error()))
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(body),
		}, nil
	}

	return events.APIGatewayProxyResponse{
		StatusCode: 200,
		Body:       strconv.FormatInt(*summary.StreamDescriptionSummary.OpenShardCount, 10),
	}, nil
}

func Handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	values, err := url.ParseQuery(request.Body)
	if err != nil {
		body, _ := json.Marshal(SlackErrorResponse(err.Error()))
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(body),
		}, nil
	}
	for key, value := range values {
		fmt.Println(fmt.Sprintf(" - %s: %s", key, value))
	}
	switch strings.ToLower(values.Get("command")) {
	case "/support":
		return SupportCommand(strings.Fields(strings.ToLower(values.Get("text"))))
	default:
		body, _ := json.Marshal(SlackErrorResponse("unsupported command."))
		return events.APIGatewayProxyResponse{
			StatusCode: 200,
			Body:       string(body),
		}, nil
	}
}

func main() {
	lambda.Start(Handler)
}
