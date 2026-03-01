/*
 * react_app.c
 *
 * Userspace application for the reaction time measurement driver.
 * The program opens /dev/react_driver and repeatedly exercises it:
 *   1) wait a random interval (100ms..2100ms)
 *   2) write a byte to the driver to arm it and turn on the LED
 *   3) block until the driver returns an 8-byte elapsed time value
 *   4) print the elapsed nanoseconds to stdout
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

#define DEVICE_PATH "/dev/react_driver"

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
