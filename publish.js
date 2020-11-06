const ghpages = require('gh-pages');

ghpages.publish('www', err => {
    if(err) {
        console.log('Error publishing to gh-pages:');
        console.log(err);
    } else {
        console.log('Successfully published to gh-pages: https://TheHorscht.github.io/LocationTracker');
    }
});