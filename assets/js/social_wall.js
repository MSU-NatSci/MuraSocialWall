
let selector = document.getElementById('sw_selector');
let updateDisplay = function(mediaList) {
    let postDivs = document.getElementsByClassName('sw_post');
    let medias = mediaList.split(',');
    for (let postDiv of postDivs) {
        let found = false;
        for (let media of medias) {
            if (postDiv.classList.contains(media + '_post')) {
                found = true;
                break;
            }
        }
        if (found)
            postDiv.style.display = 'inline-block';
        else
            postDiv.style.display = 'none';
    }
};
if (selector != null) {
    updateDisplay(selector.value);
    selector.addEventListener('change', function(e) {
        updateDisplay(selector.value);
    }, false);
}
