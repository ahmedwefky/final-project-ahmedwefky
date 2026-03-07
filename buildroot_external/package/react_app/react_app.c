/*
 * react_app.c
 *
 * Userspace application for the reaction time measurement driver.
 * The program opens /dev/react_driver and repeatedly exercises it:
 *   1) wait a random interval (100ms..2100ms)
 *   2) write a byte to the driver to arm it and turn on the LED
 *   3) block until the driver returns an 8-byte elapsed time value
 *   4) print the elapsed nanoseconds to stdout
 *   5) publish the elapsed time to Adafruit IO via MQTT
 *
 * The user can control the application via a small text menu: press
 * ENTER to run a single trial, or 'q' then ENTER to quit.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <string.h>
#include <MQTTClient.h>

#define DEVICE_PATH "/dev/react_driver"

/* Adafruit IO MQTT configuration */
#define ADAFRUIT_IO_ADDRESS "tcp://io.adafruit.com:1883"
#define ADAFRUIT_IO_USERNAME "awefky"
#define ADAFRUIT_IO_KEY "aio_BbVY556zmueF1KYFfBUD3EWmowdS"
#define ADAFRUIT_IO_FEED "awefky/feeds/reaction-time-measurement"
#define MQTT_CLIENTID "react_app_" "awefky" "_" "react_device"
#define MQTT_QOS 1
#define MQTT_TIMEOUT 10000L

static void publish_to_adafruit(uint64_t elapsed_ns);

static void run_trial(int fd)
{
    /* random delay between 100ms and 2100ms */
    int msec = (rand() % 2000) + 100;
    usleep(msec * 1000);

    /* arm driver */
    if (write(fd, "x", 1) != 1)
    {
        perror("write");
        return;
    }

    /* read 8-byte elapsed time */
    uint64_t elapsed;
    ssize_t r = read(fd, &elapsed, sizeof(elapsed));
    if (r < 0)
    {
        perror("read");
        return;
    }
    if (r != sizeof(elapsed))
    {
        fprintf(stderr, "unexpected read size: %zd\n", r);
        return;
    }

    printf("reaction time = %llu ns\n", (unsigned long long)elapsed);

    /* Publish to Adafruit IO via MQTT */
    publish_to_adafruit(elapsed);
}

static void publish_to_adafruit(uint64_t elapsed_ns)
{
    MQTTClient client;
    MQTTClient_connectOptions conn_opts = MQTTClient_connectOptions_initializer;
    int rc;
    char payload[64];

    /* Create MQTT client */
    rc = MQTTClient_create(&client, ADAFRUIT_IO_ADDRESS, MQTT_CLIENTID,
                          MQTTCLIENT_PERSISTENCE_NONE, NULL);
    if (rc != MQTTCLIENT_SUCCESS)
    {
        fprintf(stderr, "Failed to create MQTT client, code %d\n", rc);
        return;
    }

    /* Set connection options with username and password */
    conn_opts.keepAliveInterval = 20;
    conn_opts.cleansession = 1;
    conn_opts.username = ADAFRUIT_IO_USERNAME;
    conn_opts.password = ADAFRUIT_IO_KEY;

    /* Connect to broker */
    rc = MQTTClient_connect(client, &conn_opts);
    if (rc != MQTTCLIENT_SUCCESS)
    {
        fprintf(stderr, "Failed to connect to MQTT broker, code %d\n", rc);
        MQTTClient_destroy(&client);
        return;
    }

    /* Format and publish payload */
    snprintf(payload, sizeof(payload), "%llu", (unsigned long long)elapsed_ns);
    
    rc = MQTTClient_publish(client, ADAFRUIT_IO_FEED, strlen(payload),
                           payload, MQTT_QOS, 0, NULL);
    if (rc != MQTTCLIENT_SUCCESS)
    {
        fprintf(stderr, "Failed to publish to MQTT, code %d\n", rc);
    }
    else
    {
        printf("Published to %s: %s ns\n", ADAFRUIT_IO_FEED, payload);
    }

    /* Disconnect and cleanup */
    MQTTClient_disconnect(client, 10000);
    MQTTClient_destroy(&client);
}

int main(int argc, char **argv)
{
    int fd = open(DEVICE_PATH, O_RDWR);
    if (fd < 0)
    {
        perror("opening " DEVICE_PATH);
        return 1;
    }

    /* seed RNG */
    srand(time(NULL));

    printf("reaction time measurement application\n");
    printf("press ENTER to start a trial, 'q' then ENTER to quit\n");

    while (1)
    {
        int c = getchar();
        if (c == EOF) break;
        if (c == 'q')
            break;
        if (c == '\n')
        {
            run_trial(fd);
            printf("press ENTER for another, 'q' to quit\n");
        }
    }

    close(fd);
    return 0;
}
