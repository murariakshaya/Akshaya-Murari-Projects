-- List all books along with their category names
SELECT * FROM books;
SELECT * FROM book_categories;
SELECT 
	books.book_id, 
    books.title, 
    books.author,
    book_categories.category
FROM books
LEFT JOIN book_categories ON books.category_id=book_categories.id;

-- Find all books that were added in the last 30 days
SELECT * FROM books;
SELECT 
    book_id,
    title,
    author,
    description,
    added_at_timestamp
FROM books
WHERE added_at_timestamp >= NOW() - INTERVAL 30 DAY;

-- Retrieve all students who have issued more than 1 book
SELECT * FROM book_issue_log;
SELECT * FROM students;
SELECT
	student_id,
    concat(first_name, ' ', last_name) AS student_name,
    books_issued
FROM students
WHERE books_issued>1;

-- Show all books that are currently available
SELECT * FROM book_issue;
SELECT * FROM books;
SELECT
	books.book_id,
    books.title,
    books.author
FROM books
JOIN book_issue ON books.book_id=book_issue.book_id
WHERE book_issue.available_status=1;

-- Fetch all students whose email ends with example.com
SELECT * FROM students;
SELECT 
	student_id,
    concat(first_name, ' ', last_name) AS student_name,
    email_id
FROM students
WHERE email_id LIKE '%example.com';

-- Count how many books exist in each category
SELECT * FROM books;
SELECT * FROM book_categories;
SELECT 
    bc.category AS category_name,
    COUNT(b.book_id) AS total_books
FROM book_categories bc
LEFT JOIN books b 
    ON bc.id = b.category_id
GROUP BY bc.category
ORDER BY total_books DESC;

-- Identify the top 3 most borrowed books of all time
SELECT * FROM book_issue_log;
SELECT * FROM book_issue;
SELECT * FROM books;
SELECT 
    b.book_id,
    b.title,
    COUNT(bil.id) AS total_borrows
FROM books b
JOIN book_issue bi 
    ON b.book_id = bi.book_id
JOIN book_issue_log bil 
    ON bi.issue_id = bil.book_issue_id
GROUP BY 
    b.book_id, b.title
ORDER BY 
    total_borrows DESC
LIMIT 3;

-- Display students with their category name and allowed borrowing limit
SELECT * FROM students;
SELECT * FROM student_categories;
SELECT
	students.student_id,
    concat(first_name, ' ', last_name) AS student_name,
    student_categories.category,
    student_categories.max_allowed
FROM students
LEFT JOIN student_categories ON students.category=student_categories.cat_id
ORDER BY student_categories.max_allowed DESC;

-- Find all overdue books (borrowed > 7 days and not returned)
SELECT * FROM book_issue_log;
SELECT * FROM books;
SELECT * FROM book_issue;
SELECT 
    bil.id AS issue_log_id,
    b.book_id,
    b.title,
    s.student_id,
    CONCAT(s.first_name, ' ', s.last_name) AS student_name,
    bil.issued_at,
    DATE_ADD(bil.issued_at, INTERVAL 7 DAY) AS due_date,
    DATEDIFF(NOW(), bil.issued_at) AS days_out
FROM book_issue_log bil
JOIN book_issue bi 
    ON bil.book_issue_id = bi.issue_id
JOIN books b 
    ON bi.book_id = b.book_id
JOIN students s
    ON bil.student_id = s.student_id
WHERE bil.return_time IS NOT NULL
  AND bil.issued_at < NOW() - INTERVAL 7 DAY
ORDER BY days_out DESC;

-- Retrieve the total number of books issued by each academic branch
SELECT * FROM book_issue_log;
SELECT * FROM branches;
SELECT 
	branches.id,
    branches.branch,
	COUNT(book_issue_log.book_issue_id) as total_books_issued
FROM branches
JOIN book_issue_log ON branches.id=book_issue_log.id
GROUP BY branches.id;

-- Show students who were approved but never borrowed a book
SELECT * FROM students;
SELECT
	student_id,
    concat(first_name, ' ', last_name) AS student_name
FROM students
WHERE approved=1 AND books_issued=0;

-- Identify the busiest hour of book issuing (group by hour)
SELECT * FROM book_issue_log;
SELECT HOUR(book_issue_log.issued_at) AS hour_issued, count(book_issue_id) AS books_issued
FROM book_issue_log
GROUP BY hour(book_issue_log.issued_at)
ORDER BY books_issued DESC;

-- Rank categories by total number of issues
SELECT * FROM book_issue_log;
SELECT * FROM book_categories;
WITH category_issue_counts AS (
    SELECT 
        bc.id AS category_id,
        bc.category,
        COUNT(bil.id) AS total_issues
    FROM book_categories bc
    LEFT JOIN books b 
        ON bc.id = b.category_id
    LEFT JOIN book_issue bi 
        ON b.book_id = bi.book_id
    LEFT JOIN book_issue_log bil
        ON bi.issue_id = bil.book_issue_id
    GROUP BY 
        bc.id, bc.category
)
SELECT 
    category_id,
    category,
    total_issues,
    DENSE_RANK() OVER (ORDER BY total_issues DESC) AS category_rank
FROM category_issue_counts
ORDER BY category_rank;

-- For each student, show their most recent issued book
SELECT * FROM students;
SELECT * FROM book_issue_log;
SELECT * FROM book_issue;
SELECT * FROM books;
WITH ranked_issues AS (
    SELECT 
        s.student_id,
        CONCAT(s.first_name, ' ', s.last_name) AS student_name,
        b.book_id,
        b.title,
        bil.issued_at,
        ROW_NUMBER() OVER (
            PARTITION BY s.student_id 
            ORDER BY bil.issued_at DESC
        ) AS rn
    FROM students s
    JOIN book_issue_log bil 
        ON s.student_id = bil.student_id
    JOIN book_issue bi 
        ON bil.book_issue_id = bi.issue_id
    JOIN books b
        ON bi.book_id = b.book_id
)
SELECT 
    student_id,
    student_name,
    book_id,
    title AS most_recent_book,
    issued_at AS issued_on
FROM ranked_issues
WHERE rn = 1
ORDER BY student_id;

-- Compute average return time (days) per category
SELECT * FROM book_issue_log;
SELECT * FROM book_categories;
SELECT
	bc.id,
    bc.category,
    AVG(datediff(bil.return_time, bil.issued_at)) AS avg_return_days
FROM book_categories bc
JOIN books b ON bc.id=b.category_id
JOIN book_issue bi ON b.book_id=bi.book_id
JOIN book_issue_log bil ON bi.issue_id=bil.book_issue_id
WHERE bil.return_time IS NOT NULL
GROUP BY bc.id
ORDER BY avg_return_days DESC;

-- Identify the most active librarian based on number of issues handled
SELECT * FROM book_issue_log;
SELECT * FROM users;
SELECT 
    users.id,
    users.name,
    count(bil.book_issue_id) AS books_issued
FROM users
LEFT JOIN book_issue_log bil ON users.id=bil.issue_by
GROUP BY users.id
ORDER BY books_issued DESC;

-- Find students who are using ≥ 10% of their borrowing limit
SELECT * FROM student_categories;
SELECT * FROM book_issue_log;
WITH student_usage AS (
    SELECT 
        s.student_id,
        CONCAT(s.first_name, ' ', s.last_name) AS student_name,
        sc.category AS student_category,
        sc.max_allowed,
        s.books_issued,
        ROUND((s.books_issued / sc.max_allowed) * 100, 2) AS usage_percent
    FROM students s
    JOIN student_categories sc
        ON s.category = sc.cat_id
)
SELECT 
    student_id,
    student_name,
    student_category,
    max_allowed,
    books_issued,
    usage_percent
FROM student_usage
WHERE usage_percent >= 10
ORDER BY usage_percent DESC;

-- Show cumulative count of book issues by day
WITH daily_counts AS (
    SELECT 
        DATE(issued_at) AS issue_date,
        COUNT(*) AS issues_on_day
    FROM book_issue_log
    GROUP BY DATE(issued_at)
)
SELECT
    issue_date,
    issues_on_day,
    SUM(issues_on_day) OVER (
        ORDER BY issue_date
    ) AS cumulative_issues
FROM daily_counts
ORDER BY issue_date;

-- Find % contribution of each book’s issues to total library issues
WITH book_issue_counts AS (
    SELECT 
        b.book_id,
        b.title,
        COUNT(bil.id) AS total_issues_for_book
    FROM books b
    LEFT JOIN book_issue bi 
        ON b.book_id = bi.book_id
    LEFT JOIN book_issue_log bil
        ON bi.issue_id = bil.book_issue_id
    GROUP BY b.book_id, b.title
)
SELECT
    book_id,
    title,
    total_issues_for_book,
    ROUND(
        total_issues_for_book * 100.0 /
        SUM(total_issues_for_book) OVER (),
        2
    ) AS percentage_contribution
FROM book_issue_counts
ORDER BY percentage_contribution DESC;

-- Show the rolling 7-day count of book issues
WITH daily_issues AS (
    SELECT
        DATE(issued_at) AS issue_date,
        COUNT(*) AS issues_on_day
    FROM book_issue_log
    GROUP BY DATE(issued_at)
)
SELECT
    issue_date,
    issues_on_day,
    SUM(issues_on_day) OVER (
        ORDER BY issue_date
        RANGE BETWEEN INTERVAL 7 DAY PRECEDING AND CURRENT ROW
    ) AS rolling_7_day_issues
FROM daily_issues
ORDER BY issue_date;
    
    