/**
 * @file react_driver.c
 * @brief Simple reaction-time measurement character device driver.
 *
 * This driver toggles an LED and measures elapsed time until a button press.
 * It exposes a misc character device that accepts a write to start timing and
 * a read to obtain the elapsed nanoseconds as a 64-bit value.
 */
#include <linux/module.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/miscdevice.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>
#include <linux/uaccess.h>
#include <linux/ktime.h>
#include <linux/wait.h>
#include <linux/sched.h>

#define DRIVER_NAME "react_driver"

/** Base offset to add to Broadcom GPIO numbers on Raspberry Pi 4. */
#define GPIO_BASE 512

/** LED GPIO pin (physical/SoC offset + GPIO_BASE). */
#define LED_GPIO 17 + GPIO_BASE

/** Button GPIO pin (physical/SoC offset + GPIO_BASE). */
#define BTN_GPIO 27 + GPIO_BASE

/** IRQ number associated with the button GPIO. */
static int irq_number;

/** Start timestamp recorded when the test begins. */
static ktime_t start_time;

/** Measured elapsed time in nanoseconds (64-bit). */
static u64 elapsed_ns = 0;

/** Wait queue used by readers waiting for a button press. */
static DECLARE_WAIT_QUEUE_HEAD(react_queue);

/** Flag set by the IRQ handler when data is ready to read. */
static int data_ready = 0;

/**
 * @brief Interrupt handler for the button GPIO.
 * @param irq IRQ number assigned to the GPIO.
 * @param dev_id Pointer to device-specific data (unused).
 * @return IRQ_HANDLED when handled.
 *
 * Computes the elapsed time since @c start_time, turns the LED off,
 * marks data as ready and wakes up any waiting readers.
 */
static irqreturn_t react_irq_handler(int irq, void *dev_id)
{
    /* Record the time of the IRQ and compute elapsed time since start. */
    ktime_t end_time = ktime_get();

    /* elapsed_ns holds the reaction time in nanoseconds. */
    elapsed_ns = ktime_to_ns(ktime_sub(end_time, start_time));

    /* Turn the LED off to signal end of trial.*/
    gpio_set_value(LED_GPIO, 0);

    /* Mark that a sample is available and wake any waiting readers. */
    data_ready = 1;
    wake_up_interruptible(&react_queue);

    /* Indicate that the IRQ was handled. */
    return IRQ_HANDLED;
}

/**
 * @brief Start a timing trial.
 * @param file File pointer (unused).
 * @param user_buf User buffer (unused).
 * @param count Number of bytes written (returned as-is on success).
 * @param ppos File position pointer (unused).
 * @return Number of bytes written on success.
 *
 * Writing to the device arms the test: the LED is turned on and the
 * start timestamp is captured. The reader will block until a button IRQ
 * arrives and the elapsed time becomes available.
 */
static ssize_t react_write(struct file *file, const char __user *user_buf, size_t count, loff_t *ppos)
{
    /* Prepare for a new timing trial. */
    data_ready = 0;         /* clear any previous sample */
    elapsed_ns = 0;        /* reset measurement */

    /* Turn the LED on to indicate the trial has started. */
    gpio_set_value(LED_GPIO, 1);

    /* Record the start time as high-resolution kernel time. */
    start_time = ktime_get();

    /* Return the number of bytes written to follow normal write semantics. */
    return count;
}

/**
 * @brief Read the measured elapsed time.
 * @param file File pointer (unused).
 * @param user_buf User buffer to copy the 64-bit elapsed value into.
 * @param count Size of the user buffer; must be at least sizeof(u64).
 * @param ppos File position pointer (unused).
 * @return Number of bytes copied (sizeof(u64)) on success or negative errno.
 *
 * Blocks until the button IRQ has signalled that data is available.
 */
static ssize_t react_read(struct file *file, char __user *user_buf, size_t count, loff_t *ppos)
{
    ssize_t ret;

    /* Block until data_ready is non-zero or a signal interrupts the wait. */
    if (wait_event_interruptible(react_queue, data_ready != 0))
    {
        /* Interrupted by a signal, request restart or return error. */
        ret = -ERESTARTSYS;
    }
    /* Validate user buffer size: must be large enough to hold u64. */
    else if (count < sizeof(elapsed_ns))
    {
        ret = -EINVAL;
    }
    else if (copy_to_user(user_buf, &elapsed_ns, sizeof(elapsed_ns)))
    {
        /* copy_to_user failed (bad pointer in userspace). */
        ret = -EFAULT;
    }
    else
    {
        /* On success clear the ready flag so subsequent reads block until
         * the next measurement is available, and return number of bytes
         * copied. */
        data_ready = 0;
        ret = sizeof(elapsed_ns);
    }

    return ret;
}

static const struct file_operations fops = 
{
    .owner = THIS_MODULE,
    .write = react_write,
    .read = react_read,
};

static struct miscdevice react_misc_device = 
{
    .minor = MISC_DYNAMIC_MINOR,
    .name = DRIVER_NAME,
    .fops = &fops,
};

/**
 * @brief Misc device representing the react driver.
 *
 * The device is registered on module load and provides a simple
 * character interface under /dev/react_driver (or similar) where userspace
 * can write to start a trial and read back the elapsed time.
 */

/**
 * @brief Module initialization.
 * @return 0 on success or negative errno on failure.
 *
 * Requests the LED and button GPIOs, configures the button IRQ and
 * registers the misc device used by userspace.
 */
static int __init react_init(void) 
{
    int ret;
    
    pr_info("Initializing React Driver\n");

    if (!gpio_is_valid(LED_GPIO) || !gpio_is_valid(BTN_GPIO)) 
    {
        pr_err("React: Invalid GPIO\n");
        ret = -ENODEV;
    }
    else
    {
        /* Request the LED GPIO and initialize it to low. */
        ret = gpio_request(LED_GPIO, "sys_led");
        if (ret)
        {
            pr_err("React: Failed to request LED GPIO\n");
        }
        else
        {
            /* Configure LED as output and ensure it starts off. */
            gpio_direction_output(LED_GPIO, 0);

            /* Request the button GPIO for input. */
            ret = gpio_request(BTN_GPIO, "sys_btn");
            if (ret)
            {
                pr_err("React: Failed to request Button GPIO\n");
                gpio_free(LED_GPIO);
            }
            else
            {
                /* Configure the button GPIO as input. */
                gpio_direction_input(BTN_GPIO);

                /* Map the GPIO to a Linux IRQ number. */
                irq_number = gpio_to_irq(BTN_GPIO);
                
                if (irq_number < 0)
                {
                    pr_err("React: Failed to map GPIO to IRQ\n");
                    ret = irq_number;
                    gpio_free(LED_GPIO);
                    gpio_free(BTN_GPIO);
                }
                else
                {
                    /* Request a threaded/fast IRQ handler on rising edge. */
                    ret = request_irq(irq_number, react_irq_handler, IRQF_TRIGGER_RISING, "react_irq", NULL);
                    if (ret) 
                    {
                        pr_err("React: Failed to request IRQ\n");
                        gpio_free(LED_GPIO);
                        gpio_free(BTN_GPIO);
                    }
                    else
                    {
                        /* Expose the device to userspace as a misc device. */
                        ret = misc_register(&react_misc_device);
                        if (ret == 0)
                        {
                            pr_info("React Driver Loaded\n");
                        }
                        else
                        {
                            pr_err("React: Failed to register misc device\n");
                            /* Clean up the IRQ since registration failed. */
                            free_irq(irq_number, NULL);
                            gpio_free(LED_GPIO);
                            gpio_free(BTN_GPIO);
                        }
                    }
                }
            }
        }
    }
    return ret;
}

/**
 * @brief Module cleanup routine.
 *
 * Frees IRQ and GPIO resources and deregisters the misc device.
 */
static void __exit react_exit(void)
{
    /* Release IRQ and device registration, ensuring resources are freed
     * in the reverse order of acquisition. */
    free_irq(irq_number, NULL);
    misc_deregister(&react_misc_device);

    /* Turn LED off and free GPIOs. */
    gpio_set_value(LED_GPIO, 0);
    gpio_free(LED_GPIO);
    gpio_free(BTN_GPIO);

    pr_info("React Driver Unloaded\n");
}

module_init(react_init);
module_exit(react_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Ahmed");
MODULE_DESCRIPTION("React Driver");