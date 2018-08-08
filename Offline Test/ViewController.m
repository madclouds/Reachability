#import "ViewController.h"
#import "Reachability.h"

@interface ViewController ()
@property (nonatomic, strong, readonly) Reachability *reachability;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor lightGrayColor];
    _reachability = [Reachability newReachabilityWithURL:[NSURL URLWithString:@"https://planning.center"]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:MCTReachabilityStatusChangedNotification object:nil];
    [self.reachability startNotifier];
}

- (void)reachabilityChanged:(NSNotification *)notif {
    NSLog(@"Reachability Changed: %@",[self.reachability description]);
    if ([self.reachability isReachable]) {
        self.view.backgroundColor = [UIColor greenColor];
    } else {
        self.view.backgroundColor = [UIColor lightGrayColor];
    }
}


@end
