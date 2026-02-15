#include <linux/module.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/miscdevice.h>

#define DRIVER_NAME "react_driver"

/* Define file operations (fops) structure
This struct tells the kernel which functions to call when user space
opens, reads, or writes to /dev/react_driver. */
static const struct file_operations fops = 
{
    .owner = THIS_MODULE,
    /* We will add .read and .write functions here later */
};

/* Define the misc device structure */
static struct miscdevice react_misc_device = 
{
    .minor = MISC_DYNAMIC_MINOR, /* Let the kernel pick a free number */
    .name = DRIVER_NAME,         /* This creates /dev/react_driver */
    .fops = &fops,               /* Link to our file operations */
};

static int __init react_init(void)
{
    int ret;

    /* Register the device */
    ret = misc_register(&react_misc_device);
    if (ret)
    {
        pr_err("Failed to register the react misc device\n");
    }
    else
    {
        pr_info("React Driver Loaded\n");
    }

    return ret;
}

static void __exit react_exit(void)
{
    /* Deregister the device */
    misc_deregister(&react_misc_device);
    pr_info("React Driver Unloaded\n");
}

module_init(react_init);
module_exit(react_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Ahmed Wefky");
MODULE_DESCRIPTION("React Driver Skeleton");