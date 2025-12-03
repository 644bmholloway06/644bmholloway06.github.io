/**
 * KDL Home Page Callback Form Script
 * Handles form submission and validation for the callback request.
 */

document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('callback-form');
    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        // Simple validation
        const name = form.elements['name'].value.trim();
        const phone = form.elements['phone'].value.trim();
        const message = form.elements['message'].value.trim();

        if (!name || !phone) {
            alert('Please enter your name and phone number.');
            return;
        }

        // Prepare data
        const data = {
            name,
            phone,
            message
        };

        try {
            // Replace with your actual API endpoint
            const response = await fetch('/api/callback', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });

            if (response.ok) {
                alert('Thank you! We will call you back soon.');
                form.reset();
            } else {
                alert('Sorry, there was a problem submitting your request.');
            }
        } catch (error) {
            alert('Network error. Please try again later.');
        }
    });
});