
let selector = document.getElementById('sw_selector');
let updateDisplay = function(media) {
    let postDivs = document.getElementsByClassName('sw_post');
    for (let postDiv of postDivs) {
        if (media == 'all' || postDiv.classList.contains(media + '_post'))
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
